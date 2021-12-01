init:
	@terraform init

plan:
	@terraform plan -out=elastic.tfplan

gke: init plan
	@terraform apply elastic.tfplan

clean:
	@terraform destroy
	@rm elastic.tfplan

.PHONY: init gke elastic