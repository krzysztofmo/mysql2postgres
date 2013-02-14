# -*- encoding : utf-8 -*-

class Mysql2psql
  
  class GeneralError < StandardError
	end

  class ConfigurationError < StandardError
	end
  class UninitializedValueError < ConfigurationError
	end
  class ConfigurationFileNotFound < ConfigurationError
	end
  class ConfigurationFileInitialized < ConfigurationError
	end	
	class ConversionError < StandardError
  end
  class CopyCommandError < ConversionError
  end

end