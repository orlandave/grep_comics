# == Schema Information
#
# Table name: weekly_lists
#
#  id             :integer          not null, primary key
#  list           :text
#  wednesday_date :date
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

class WeeklyList < ApplicationRecord
  has_many :comics

  class << self
    def current_week_list
      WeeklyList.order(wednesday_date: :desc).first
    end
  end

  def fetch_comics
    self.comics.eager_load(:publisher).preload(:writers, :artists, :cover_artists).order('publishers.name', :title, :issue_number)
  end

end
