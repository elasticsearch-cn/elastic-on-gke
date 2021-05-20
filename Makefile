region := asia-east1
#region := us-central1

init:
	@[ -d deploy ] || mkdir -p deploy 
	@[ -f deploy/cert.yml ] || cp -a templates/cert.yml deploy/
	@[ -f deploy/kbn.yml ] || cp -a templates/kbn.yml deploy/
	@[ -f deploy/lb.yml ] || cp -a templates/lb.yml deploy/
	@[ -f deploy/apm.yml ] || cp -a templates/apm.yml deploy/

init_single: init
	@cp -a templates/es.single_node.yml deploy/es.yml

init_allrole: init
	@sed 's/asia-east1/$(region)/g' templates/es.all_role.yml > deploy/es.yml

init_prod: init
	@sed 's/asia-east1/$(region)/g' templates/es.prod.yml > deploy/es.yml

.PHONY: init init_single init_allrole init_prod
