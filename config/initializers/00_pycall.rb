python_path = Rails.root.join('venv', 'bin', 'python').to_s
ENV['PYTHON'] = python_path
ENV['PYTHONPATH'] = Rails.root.join('venv', 'lib', 'python3.12', 'site-packages').to_s
ENV['LD_LIBRARY_PATH'] = Rails.root.join('venv', 'lib').to_s
ENV['LIBPYTHON'] = '/Users/ricardogontarz/.asdf/installs/python/3.12.3/lib/libpython3.12.dylib'


require 'pycall/import'
Rails.logger.info "[PyCall] Using Python at #{ENV['PYTHON']}" if Rails.env.development?
Rails.logger.info "[PyCall] Python path: #{ENV['PYTHONPATH']}" if Rails.env.development?
