To install Elasticsearch on OSX
```install java```  
```brew install elasticsearch```  
```mrt add elasticsearch```  

To start Elasticsearch
```
elasticsearch --config=/usr/local/opt/elasticsearch/config/elasticsearch.yml
```  

Need to figue a start up and stop service for elasticsearch  
https://github.com/andrewreedy/meteor-elasticsearch

TODO:  
Implement english analyzer
Fix Pagination
Reset ES when Mongo is reset in admin panel
Create a generator for ES queries
Creating a Person pushes it into ES twice
Create function that validates ES query