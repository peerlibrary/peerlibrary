To install Elasticsearch on OSX
```install java```  
```brew install elasticsearch```  
```mrt add elasticsearch```  

To start Elasticsearch
```
elasticsearch --config=/usr/local/opt/elasticsearch/config/elasticsearch.yml
```  


using http://www.elastichq.org/ to monitor local ES cluster and response time

changing a publication reindexes it, but that doesn't change a pre-existing session  

need to check that what is returned by es can be seen by user, for example, if es returns 50 results, but they are all
private, the user will not be able to see anything