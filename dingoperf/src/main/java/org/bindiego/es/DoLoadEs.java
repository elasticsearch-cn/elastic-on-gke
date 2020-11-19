package org.bindiego.es;

import org.apache.commons.configuration.PropertiesConfiguration;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.bindiego.util.Config;

import org.json.JSONObject;

import org.elasticsearch.client.RestClient;
import org.elasticsearch.client.Request;
import org.elasticsearch.client.Response;
import org.elasticsearch.client.RestClientBuilder;
import org.elasticsearch.client.RestHighLevelClient;
import org.elasticsearch.client.ResponseListener;
import org.elasticsearch.client.RestClientBuilder.HttpClientConfigCallback;
import org.elasticsearch.client.ResponseException;

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

class DoLoadEs implements Runnable {
    private DoLoadEs() {}

    public DoLoadEs(final RestClient restClient, final String bulkStr) {
        // Instantiate or get the current Global config
        config = Config.getConfig();

        this.restClient = restClient;
        this.bulkStr = bulkStr;
    }

    @Override
    public void run() {
        try {
            String endPoint = String.format(
                "/%s/_bulk",
                config.getProperty("es.index").toString());

            HttpEntity requestBody = new NStringEntity(
                bulkStr, ContentType.APPLICATION_JSON);
            Request request = new Request("POST", endPoint);
            request.addParameters(Collections.emptyMap());
            request.setEntity(requestBody);

            int numThreads = Integer.parseInt(
                config.getProperty("es.ingest.paralism.loops").toString());
            for (int i = 0; i < numThreads; ++i) {
                if (config.getProperty("es.client.async").toString().equalsIgnoreCase("false")) {
                    Response response = restClient.performRequest(request);
                } else {
                    restClient.performRequestAsync(request, new ResponseListener() {
                        @Override
                        public void onSuccess(Response response) {
                        }

                        @Override 
                        public void onFailure(Exception ex) {
                            if(ex instanceof ResponseException){
                                logger.error("ResponseException", ex);
                            } else {
                                int retry = Integer.parseInt(
                                    config.getProperty("es.client.async.fail.retry").toString());
                                for (int i = 0; i < retry; ++i) {
                                    try{
                                        //use sync method to resent request
                                        Response response = restClient.performRequest(request);
                                        logger.debug("resent request succeed");
                                        return;
                                    } catch (Exception e){
                                        logger.error("retry failed.");
                                        try{
                                            //sleep if failed again
                                            Thread.sleep(Integer.parseInt(
                                                config.getProperty("es.client.async.fail.retry.delay.ms").toString()));
                                        }catch (Exception exception) {

                                        }
                                    }
                                }
                            }
                        }
                    });

                    Thread.sleep(Integer.parseInt(
                        config.getProperty("es.client.async.pace.ms").toString()));
                }
            }
        } catch (Exception ex) {
            logger.error("Request exception", ex);
        }

        Runtime.getRuntime().addShutdownHook(new Thread(){
            public void run() {
                try {
                    logger.info("worker shutting down, close connection");

                    if (null != restClient) {
                        restClient.close();
                    }
                } catch (IOException ex) {
                    Thread.currentThread().interrupt();

                    logger.error("worker shutdown Hook Error", ex);
                }
            }
        });
    }

    private static final Logger logger =
        LogManager.getFormatterLogger(DoLoadEs.class.getName());

    private PropertiesConfiguration config;

    private String bulkStr;

    private RestClient restClient;
}
