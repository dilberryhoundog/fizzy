module WriterAffinity
  extend ActiveSupport::Concern

  class_methods do
    def skip_writer_affinity(**)
      before_action :set_writer_affinity_opt_out_header, **
    end
  end

  private
    def set_writer_affinity_opt_out_header
      response.headers["X-Writer-Affinity"] = "false"
    end
end
