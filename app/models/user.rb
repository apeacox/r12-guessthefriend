class User < ActiveRecord::Base
  attr_accessible :name, :oauth_expires_at, :oauth_token, :provider, :uid

  def self.from_omniauth(auth)
    where(auth.slice(:provider, :uid)).first_or_initialize.tap do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.name = auth.info.name
      user.oauth_token = auth.credentials.token
      user.oauth_expires_at = Time.at(auth.credentials.expires_at)
      user.save!
    end
  end

  # Find all friends
  def get_friends
    facebook.get_connections :me, :friends
  end

  private
  # Facebook API wrapper
  def facebook
    @api ||= Koala::Facebook::API.new(self.oauth_token)
  end
end
