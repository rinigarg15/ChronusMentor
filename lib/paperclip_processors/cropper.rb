module Paperclip
  class Cropper < Thumbnail

    def transformation_command
      if crop_command
        @current_geometry.width = @attachment.instance.crop_w.to_f
        @current_geometry.height = @attachment.instance.crop_h.to_f
        crop_command + super
      else
        super
      end
    end
    
    def crop_command
      target = @attachment.instance
      if target.cropping?
        ["-rotate", "#{target.rotate}", "-crop", "#{target.crop_w}x#{target.crop_h}+#{target.crop_x}+#{target.crop_y}", "+repage"]
      end
    end
  end
end
