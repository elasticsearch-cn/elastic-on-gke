#!/bin/bash

kubectl -n elastic-system logs -f statefulset.apps/elastic-operator
