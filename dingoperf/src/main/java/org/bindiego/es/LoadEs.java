package org.bindiego.es;

import org.apache.commons.configuration.PropertiesConfiguration;
import org.apache.commons.io.FileUtils;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.bindiego.util.Config;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.util.Iterator;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.Executors;

import org.elasticsearch.client.RestClient;
import org.elasticsearch.client.Request;
import org.elasticsearch.client.Response;
import org.elasticsearch.client.RestClientBuilder;
import org.elasticsearch.client.RestHighLevelClient;
import org.elasticsearch.client.ResponseListener;
import org.elasticsearch.client.RestClientBuilder.HttpClientConfigCallback;

import org.apache.http.HttpEntity;
import org.apache.http.HttpHost;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.CredentialsProvider;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.conn.ssl.TrustSelfSignedStrategy;
import org.apache.http.conn.ssl.TrustStrategy;
import org.apache.http.entity.BufferedHttpEntity;
import org.apache.http.entity.ContentType;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.apache.http.nio.conn.ssl.SSLIOSessionStrategy;
import org.apache.http.nio.entity.NStringEntity;
import org.apache.http.ssl.SSLContexts;
import org.apache.http.impl.nio.reactor.IOReactorConfig;
import org.apache.http.impl.nio.client.HttpAsyncClientBuilder;
import org.apache.http.ssl.SSLContextBuilder;
import org.apache.http.conn.ssl.NoopHostnameVerifier;

import javax.annotation.Nonnull;
import javax.annotation.Nullable;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.Serializable;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.ListIterator;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.function.Predicate;
import java.security.cert.X509Certificate;
import java.security.NoSuchAlgorithmException;
import java.security.KeyManagementException;

import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.databind.ser.std.StdSerializer;

import org.joda.time.Duration;

public class LoadEs extends Thread {
    public LoadEs() {
        // Instantiate or get the current Global config
        this.config = Config.getConfig();

        this.restClient = createRestClient();
    }

    private RestClient createRestClient() {
        RestClientBuilder restClientBuilder = null;

        try {
            final CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
            credentialsProvider.setCredentials(
                AuthScope.ANY, new UsernamePasswordCredentials(
                    config.getProperty("es.user").toString(), 
                    config.getProperty("es.pass").toString()));

            HttpHost[] esHosts = new HttpHost[1];
            URL url = new URL(config.getProperty("es.connection").toString());
            esHosts[0] = new HttpHost(url.getHost(), url.getPort(), url.getProtocol());

            logger.debug("ES connection, host: %s, port: %d, protocol: %s\nuser: %s, password: %s", 
                url.getHost(), url.getPort(), url.getProtocol(),
                config.getProperty("es.user").toString(), 
                config.getProperty("es.pass").toString());

            restClientBuilder = RestClient.builder(esHosts);

            restClientBuilder.setHttpClientConfigCallback(
                new HttpClientConfigCallback() {
                    @Override
                    public HttpAsyncClientBuilder customizeHttpClient(
                        HttpAsyncClientBuilder httpAsyncClientBuilder) {
                            httpAsyncClientBuilder.setDefaultCredentialsProvider(credentialsProvider);
                            
                            httpAsyncClientBuilder.setDefaultIOReactorConfig(
                                IOReactorConfig.custom()
                                    .setIoThreadCount(Integer.parseInt(
                                        config.getProperty("es.ingest.threads").toString()))
                                    .build());

                            try {
                                // SSLContext context = SSLContext.getInstance("SSL");
                                SSLContext context = SSLContext.getInstance("TLS");
            
                                context.init(null, new TrustManager[] {
                                    new X509TrustManager() {
                                        public void checkClientTrusted(X509Certificate[] chain, String authType) {}
            
                                        public void checkServerTrusted(X509Certificate[] chain, String authType) {}
            
                                        public X509Certificate[] getAcceptedIssuers() { return null; }
                                    }
                                }, null);

                                httpAsyncClientBuilder.setSSLContext(context)
                                    .setSSLHostnameVerifier(NoopHostnameVerifier.INSTANCE);
                            } catch (NoSuchAlgorithmException ex) {
                                logger.error("Error when setup dummy SSLContext", ex);
                            } catch (KeyManagementException ex) {
                                logger.error("Error when setup dummy SSLContext", ex);
                            } catch (Exception ex) {
                                logger.error("Error when setup dummy SSLContext", ex);
                            }

                            return httpAsyncClientBuilder;
                        }
                }
            );

            /*
            restClientBuilder.setRequestConfigCallback(
                new RestClientBuilder.RequestConfigCallback() {
                    @Override
                    public RequestConfig.Builder customizeRequestConfig(
                            RequestConfig.Builder requestConfigBuilder) {
                        if (null != getConnectTimeout()) {
                            requestConfigBuilder.setConnectTimeout(getConnectTimeout());
                        }
                        if (null != getSocketTimeout()) {
                            requestConfigBuilder.setSocketTimeout(getSocketTimeout());
                        }

                        return requestConfigBuilder;
                    }
                }
            );
            */
        } catch (Exception ex) {
            logger.error("Init error", ex);
        } finally {
            return restClientBuilder.build();
        }
    }

    @Override
    public void run() {
        try {
            ArrayList<String> batch = new ArrayList<>();

            int batchSize = Integer.parseInt(
                config.getProperty("es.bulk.size").toString());
            for (int i = 0; i < batchSize; ++i) {
                batch.add(String.format("{ \"index\" : %s }%n%s%n", 
                    String.format("{ \"_index\": \"%s\" }", config.getProperty("es.index").toString()),
                    this.payload));
            }

            StringBuilder bulkRequest = new StringBuilder();
            for (String json : batch) {
                bulkRequest.append(json);
            }
            String bulkStr = bulkRequest.toString();

            // Run threads
            int numThreads = Integer.parseInt(
                config.getProperty("es.ingest.paralism").toString());
            exec = Executors.newFixedThreadPool(numThreads);

            for (int i = 0; i < numThreads; ++i) {
                if (config.getProperty("es.client.share").toString().equalsIgnoreCase("true")) {
                    exec.execute(new DoLoadEs(this.restClient, bulkStr));
                } else {
                    exec.execute(new DoLoadEs(createRestClient(), bulkStr));
                }
            }

            Runtime.getRuntime().addShutdownHook(new Thread(){
                public void run() {
                    try {
                        logger.info("Shutting down test");

                        if (null != restClient) {
                            restClient.close();
                        }

                        exec.shutdown();
                    } catch (IOException ex) {
                        Thread.currentThread().interrupt();

                        logger.error("Shutdown Hook Error", ex);
                    }
                }
            });
        } catch (Exception ex) {
            logger.error("LoadES failed", ex);
        }
    }

    private static final Logger logger =
        LogManager.getFormatterLogger(LoadEs.class.getName());

    private PropertiesConfiguration config;

    private ExecutorService exec;
    private BlockingQueue<Runnable> bq;

    private final String payload = "{ \"severity\":\"INFO\", \"resource\":{ \"type\":\"http_load_balancer\", \"labels\":{ \"forwarding_rule_name\":\"k8s2-fs-44tbma2y-default-dingo-elk-ingress-ghptgyop\", \"project_id\":\"google.com:bin-wus-learning-center\", \"target_proxy_name\":\"k8s2-ts-44tbma2y-default-dingo-elk-ingress-ghptgyop\", \"zone\":\"global\", \"backend_service_name\":\"k8s1-8a43299b-default-dingo-kbn-svc-5601-8727be7d\", \"url_map_name\":\"k8s2-um-44tbma2y-default-dingo-elk-ingress-ghptgyop\" } }, \"receiveTimestamp\":\"2020-09-25T13:34:47.555808575Z\", \"spanId\":\"8be145b3c0d526b8\", \"trace\":\"projects/google.com:bin-wus-learning-center/traces/8430fa78a2a513625f5bba3a03760475\", \"@timestamp\":\"2020-09-24T16:34:47.480829Z\", \"logName\":\"projects/google.com:bin-wus-learning-center/logs/requests\", \"jsonPayload\":{ \"@type\":\"type.googleapis.com/google.cloud.loadbalancing.type.LoadBalancerLogEntry\", \"statusDetails\":\"response_sent_by_backend\" }, \"httpRequest\":{ \"referer\":\"https://k8na.bindiego.com/s/google-cloud/app/discover\", \"remoteIp\":\"104.134.27.7\", \"latency\":\"0.008784s\", \"requestMethod\":\"GET\", \"responseSize\":\"303\", \"userAgent\":\"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36\", \"geo\":{ \"continent_name\":\"Asia\", \"country_iso_code\":\"TW\", \"location\":{ \"lon\":121, \"lat\":23.5 } }, \"backendLatency\":0.008784, \"requestUrl\":\"https://k8na.bindiego.com/s/google-cloud/internal/security/me\", \"requestDomain\":\"k8na.bindiego.com\", \"serverIp\":\"10.32.0.16\", \"requestSize\":\"43\", \"requestProtocol\":\"https\", \"user_agent\":{ \"original\":\"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36\", \"os\":{ \"name\":\"Mac OS X\", \"version\":\"10.15.6\", \"full\":\"Mac OS X 10.15.6\" }, \"name\":\"Chrome\", \"device\":{ \"name\":\"Mac\" }, \"version\":\"85.0.4183.121\" }, \"status\":200 }, \"insertId\":\"r72qohfb7wzwd\" }";

    private RestClient restClient;
}
