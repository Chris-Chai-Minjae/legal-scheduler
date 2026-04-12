module BlogHelper
  def seo_score_class(score)
    return "score-low" if score.nil?
    case score
    when 80..100 then "score-high"
    when 50..79  then "score-mid"
    else              "score-low"
    end
  end
end
