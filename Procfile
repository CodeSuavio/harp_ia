release: bin/rails db:migrate
web: SOLID_QUEUE_IN_PUMA=true bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
