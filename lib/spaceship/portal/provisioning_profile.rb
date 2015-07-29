module Spaceship
  module Portal
    # Represents a provisioning profile of the Apple Dev Portal
    class ProvisioningProfile < PortalBase
      # @return (String) The ID generated by the Dev Portal
      #   You'll probably not really need this value
      # @example
      #   "2MAY7NPHAA"
      attr_accessor :id

      # @return (String) The UDID of this provisioning profile
      #   This value is used for example for code signing
      #   It is also contained in the actual profile
      # @example
      #   "23d7df3b-9767-4e85-a1ea-1df4d8f32fec"
      attr_accessor :uuid

      # @return (DateTime) The date and time of when the profile
      #   expires.
      # @example
      #   #<DateTime: 2015-11-25T22:45:50+00:00 ((2457352j,81950s,0n),+0s,2299161j)>
      attr_accessor :expires

      # @return (String) The profile distribution type. You probably want to
      #   use the class type to detect the profile type instead of this string.
      # @example AppStore Profile
      #     "store"
      # @example AdHoc Profile
      #     "adhoc"
      # @example Development Profile
      #     "limited"
      attr_accessor :distribution_method

      # @return (String) The name of this profile
      # @example
      #   "com.krausefx.app AppStore"
      attr_accessor :name

      # @return (String) The status of this profile
      # @example Active (profile is fine)
      #   "Active"
      # @example Expired (time ran out)
      #   "Expired"
      # @example Invalid (e.g. code signing identity not available any more)
      #   "Invalid"
      attr_accessor :status

      # @return (String) The type of the profile (development or distribution).
      #   You'll probably not need this value
      # @example Distribution
      #   "iOS Distribution"
      # @example Development
      #   "iOS Development"
      attr_accessor :type

      # @return (String) This will always be "2"
      # @example
      #   "2"
      attr_accessor :version

      # @return (String) The supported platform for this profile
      # @example
      #   "ios"
      attr_accessor :platform

      # No information about this attribute
      attr_accessor :managing_app

      # A reference to the app this profile is for.
      # You can then easily access the value directly
      # @return (App) The app this profile is for
      #
      # @example Example Value
      #   <Spaceship::App
      #     @app_id="2UMR2S6PAA"
      #     @name="App Name"
      #     @platform="ios"
      #     @prefix="5A997XSAAA"
      #     @bundle_id="com.krausefx.app"
      #     @is_wildcard=false
      #     @dev_push_enabled=false
      #     @prod_push_enabled=false>
      #
      # @example Usage
      #   profile.app.name
      attr_accessor :app

      # @return (Array) A list of certificates used for this profile
      # @example Example Value
      #  [
      #   <Spaceship::Certificate::Production
      #     @status=nil
      #     @id="XC5PH8D4AA"
      #     @name="iOS Distribution"
      #     @created=nil
      #     @expires=#<DateTime: 2015-11-25T22:45:50+00:00 ((2457352j,81950s,0n),+0s,2299161j)>
      #     @owner_type="team"
      #     @owner_name=nil
      #     @owner_id=nil
      #     @type_display_id="R58UK2EWAA">]
      #  ]
      #
      # @example Usage
      #   profile.certificates.first.id
      attr_accessor :certificates

      # @return (Array) A list of devices this profile is enabled for.
      #   This will always be [] for AppStore profiles
      #
      # @example Example Value
      #  <Spaceship::Device
      #    @id="WXQ7V239BE"
      #    @name="Grahams iPhone 4s"
      #    @udid="ba0ac7d70f7a14c6fa02ef0e02f4fe9c5178e2f7"
      #    @platform="ios"
      #    @status="c">]
      #
      # @example Usage
      #  profile.devices.first.name
      attr_accessor :devices

      attr_mapping({
        'provisioningProfileId' => :id,
        'UUID' => :uuid,
        'dateExpire' => :expires,
        'distributionMethod' => :distribution_method,
        'name' => :name,
        'status' => :status,
        'type' => :type,
        'version' => :version,
        'proProPlatform' => :platform,
        'managingApp' => :managing_app,
        'appId' => :app
      })

      class << self
        # @return (String) The profile type used for web requests to the Dev Portal
        # @example
        #  "limited"
        #  "store"
        #  "adhoc"
        #  "inhouse"
        def type
          raise "You cannot create a ProvisioningProfile without a type. Use a subclass."
        end

        # Create a new object based on a hash.
        # This is used to create a new object based on the server response.
        def factory(attrs)
          # Ad Hoc Profiles look exactly like App Store profiles, but usually include devices
          attrs['distributionMethod'] = 'adhoc' if attrs['distributionMethod'] == 'store' && attrs['devices'].size > 0
          # available values of `distributionMethod` at this point: ['adhoc', 'store', 'limited']

          klass = case attrs['distributionMethod']
          when 'limited'
            Development
          when 'store'
            AppStore
          when 'adhoc'
            AdHoc
          when 'inhouse'
            InHouse
          else
            raise "Can't find class '#{attrs['distributionMethod']}'"
          end

          attrs['appId'] = App.factory(attrs['appId'])
          attrs['devices'].map! { |device| Device.factory(device) }
          attrs['certificates'].map! { |cert| Certificate.factory(cert) }

          klass.client = @client
          klass.new(attrs)
        end

        # @return (String) The human readable name of this profile type.
        # @example
        #  "AppStore"
        #  "AdHoc"
        #  "Development"
        #  "InHouse"
        def pretty_type
          name.split('::').last
        end

        # Create a new provisioning profile
        # @param name (String): The name of the provisioning profile on the Dev Portal
        # @param bundle_id (String): The app identifier, this paramter is required
        # @param certificate (Certificate): The certificate that should be used with this
        #   provisioning profile. You can also pass an array of certificates to this method. This will
        #   only work for development profiles
        # @param devices (Array) (optional): An array of Device objects that should be used in this profile.
        #  It is recommend to not pass devices as spaceship will automatically add all devices for AdHoc
        #  and Development profiles and add none for AppStore and Enterprise Profiles
        # @return (ProvisioningProfile): The profile that was just created
        def create!(name: nil, bundle_id: nil, certificate: nil, devices: [])
          raise "Missing required parameter 'bundle_id'" if bundle_id.to_s.empty?
          raise "Missing required parameter 'certificate'. e.g. use `Spaceship::Certificate::Production.all.first`" if certificate.to_s.empty?

          app = Spaceship::App.find(bundle_id)
          raise "Could not find app with bundle id '#{bundle_id}'" unless app

          # Fill in sensible default values
          name ||= [bundle_id, self.pretty_type].join(' ')

          devices = [] if (self == AppStore or self == InHouse) # App Store Profiles MUST NOT have devices

          certificate_parameter = certificate.collect { |c| c.id } if certificate.kind_of? Array
          certificate_parameter ||= [certificate.id]

          # Fix https://github.com/KrauseFx/fastlane/issues/349
          certificate_parameter = certificate_parameter.first if certificate_parameter.count == 1

          if devices.nil? or devices.count == 0
            if self == Development or self == AdHoc
              # For Development and AdHoc we usually want all devices by default
              devices = Spaceship::Device.all
            end
          end

          profile = client.with_retry do
            client.create_provisioning_profile!(name,
                                                self.type,
                                                app.app_id,
                                                certificate_parameter,
                                                devices.map {|d| d.id} )
          end

          self.new(profile)
        end

        # @return (Array) Returns all profiles registered for this account
        #  If you're calling this from a subclass (like AdHoc), this will
        #  only return the profiles that are of this type
        def all
          profiles = client.provisioning_profiles.map do |profile|
            self.factory(profile)
          end

          # filter out the profiles managed by xcode
          profiles.delete_if do |profile|
            profile.managed_by_xcode?
          end

          return profiles if self == ProvisioningProfile

          # only return the profiles that match the class
          profiles.select do |profile|
            profile.class == self
          end
        end

        # @return (Array) Returns an array of provisioning
        #   profiles matching the bundle identifier
        #   Returns [] if no profiles were found
        #   This may also contain invalid or expired profiles
        def find_by_bundle_id(bundle_id)
          all.find_all do |profile|
            profile.app.bundle_id == bundle_id
          end
        end

      end

      # Represents a Development profile from the Dev Portal
      class Development < ProvisioningProfile
        def self.type
          'limited'
        end
      end

      # Represents an AppStore profile from the Dev Portal
      class AppStore < ProvisioningProfile
        def self.type
          'store'
        end
      end

      # Represents an AdHoc profile from the Dev Portal
      class AdHoc < ProvisioningProfile
        def self.type
          'adhoc'
        end
      end

      # Represents an Enterprise InHouse profile from the Dev Portal
      class InHouse < ProvisioningProfile
        def self.type
          'inhouse'
        end
      end

      # Download the current provisioning profile. This will *not* store
      # the provisioning profile on the file system. Instead this method
      # will return the content of the profile.
      # @return (String) The content of the provisioning profile
      #  You'll probably want to store it on the file system
      # @example
      #  File.write("path.mobileprovision", profile.download)
      def download
        client.download_provisioning_profile(self.id)
      end

      # Delete the provisioning profile
      def delete!
        client.delete_provisioning_profile!(self.id)
      end

      # Repair an existing provisioning profile
      # alias to update!
      # @return (ProvisioningProfile) A new provisioning profile, as
      #  the repair method will generate a profile with a new ID
      def repair!
        update!
      end

      # Updates the provisioning profile from the local data
      # e.g. after you added new devices to the profile
      # This will also update the code signing identity if necessary
      # @return (ProvisioningProfile) A new provisioning profile, as
      #  the repair method will generate a profile with a new ID
      def update!
        unless certificate_valid?
          if self.kind_of? Development
            self.certificates = [Spaceship::Certificate::Development.all.first]
          elsif self.kind_of? InHouse
            self.certificates = [Spaceship::Certificate::InHouse.all.first]
          else
            self.certificates = [Spaceship::Certificate::Production.all.first]
          end
        end

        client.with_retry do
          client.repair_provisioning_profile!(id, name, distribution_method, app.app_id, certificates.map { |c| c.id }, devices.map { |d| d.id })
        end

        # We need to fetch the provisioning profile again, as the ID changes
        profile = Spaceship::ProvisioningProfile.all.find do |profile|
          profile.name == self.name # we can use the name as it's valid
        end

        return profile
      end

      # Is the certificate of this profile available?
      # @return (Bool) is the certificate valid?
      def certificate_valid?
        return false if (certificates || []).count == 0
        certificates.each do |c|
          if Spaceship::Certificate.all.collect { |s| s.id }.include?(c.id)
            return true
          end
        end
        return false
      end

      # @return (Bool) Is the current provisioning profile valid?
      def valid?
        return (status == 'Active' and certificate_valid?)
      end

      # @return (Bool) Is this profile managed by Xcode?
      def managed_by_xcode?
        managing_app == 'Xcode'
      end
    end
  end
end
