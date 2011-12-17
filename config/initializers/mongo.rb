MongoMapper.config = { 
  Rails.env => { 'uri' => ENV['MONGOHQ_URL'] || 
                          'mongodb://test:test@staff.mongohq.com:10003/app2029342' } }

MongoMapper.connect(Rails.env)
#MongoMapper.database = "test"
