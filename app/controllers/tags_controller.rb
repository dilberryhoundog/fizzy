class TagsController < ApplicationController
  before_action :set_bubble, only: %i[ new create ]
  before_action :set_tag, only: :destroy

  def index
    @tags = Tag.all
  end

  def new
  end

  def create
    @bubble.tags << Tag.find_or_create_by!(tag_params)
    redirect_to @bubble
  end

  def destroy
    @tag.destroy
    redirect_to tags_path
  end

  private
    def tag_params
      params.require(:tag).permit(:title)
    end

    def set_tag
      @tag = Tag.find(params[:id])
    end

    def set_bubble
      @bubble = Bubble.find(params[:bubble_id])
    end
end
