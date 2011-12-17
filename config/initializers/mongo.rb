MongoMapper.config = { 
  Rails.env => { 'uri' => ENV['MONGOHQ_URL'] || 
                          'mongodb://localhost/test' } }

MongoMapper.connect(Rails.env)

#MongoMapper.database = "app2029342"
