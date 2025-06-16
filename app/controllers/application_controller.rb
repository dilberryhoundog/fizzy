class ApplicationController < ActionController::Base
  include Authentication, CurrentTimezone, SetPlatform, WriterAffinity

  stale_when_importmap_changes
  allow_browser versions: :modern
end
