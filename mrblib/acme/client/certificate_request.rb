class Acme::Client::CertificateRequest
  extend Forwardable

  DEFAULT_KEY_LENGTH = 2048
  DEFAULT_DIGEST = OpenSSL::Digest::SHA256
  SUBJECT_KEYS = {
    common_name:         'CN',
    country_name:        'C',
    organization_name:   'O',
    organizational_unit: 'OU',
    state_or_province:   'ST',
    locality_name:       'L'
  }.freeze

  attr_reader :private_key, :common_name, :names, :subject

  def_delegators :csr, :to_pem, :to_der

  def initialize(common_name=nil, names=[], private_key=generate_private_key, subject={}, digest=DEFAULT_DIGEST.new)
    @digest = digest
    @private_key = private_key
    @subject = normalize_subject(subject)
    @common_name = common_name || @subject[SUBJECT_KEYS[:common_name]] || @subject[:common_name]
    @names = names.to_a.dup
    normalize_names
    @subject[SUBJECT_KEYS[:common_name]] ||= @common_name
    validate_subject
  end

  def csr
    @csr ||= generate
  end

  private

  def generate_private_key
    OpenSSL::PKey::RSA.new(DEFAULT_KEY_LENGTH)
  end

  def normalize_subject(subject)
    @subject = subject.each_with_object({}) do |(key, value), hash|
      hash[SUBJECT_KEYS.fetch(key, key)] = value.to_s
    end
  end

  def normalize_names
    if @common_name
      @names.unshift(@common_name) unless @names.include?(@common_name)
    else
      raise ArgumentError, 'No common name and no list of names given' if @names.empty?
      @common_name = @names.first
    end
  end

  def validate_subject
    validate_subject_attributes
    validate_subject_common_name
  end

  def validate_subject_attributes
    extra_keys = @subject.keys - SUBJECT_KEYS.keys - SUBJECT_KEYS.values
    return if extra_keys.empty?
    raise ArgumentError, "Unexpected subject attributes given: #{extra_keys.inspect}"
  end

  def validate_subject_common_name
    return if @common_name == @subject[SUBJECT_KEYS[:common_name]]
    raise ArgumentError, 'Conflicting common name given in arguments and subject'
  end

  def generate
    OpenSSL::X509::Request.new.tap do |csr|
      csr.public_key = @private_key
#      csr.subject = generate_subject
      csr.version = 2
      add_extension(csr)
      csr.sign @private_key, @digest
    end
  end
end
