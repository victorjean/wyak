MongoMapper.config = { 
  Rails.env => { 'uri' => ENV['MONGOHQ_URL'] || 
                          'mongodb://rotostarter:rotopass@ds031847.mongolab.com:31847/heroku_app2029342' } }

MongoMapper.connect(Rails.env)
#MongoMapper.database = "test"
