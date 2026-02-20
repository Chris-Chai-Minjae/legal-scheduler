class BlogDocument < ApplicationRecord
  belongs_to :user
  has_one_attached :file

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  # 파일 유효성 검사
  validates :file, presence: true, on: :create
  validate :validate_file_content_type
  validate :validate_file_size

  scope :ready_for_rag, -> { where(status: :ready) }
  scope :by_tag, ->(tag) { where(tag: tag) if tag.present? }

  # 파일 업로드 후 메타데이터 자동 설정
  before_save :set_file_metadata, if: -> { file.attached? && (filename.blank? || file_type.blank? || file_size.blank?) }

  private

  # ActiveStorage 파일의 content_type 검증
  def validate_file_content_type
    return unless file.attached?

    allowed_types = %w[application/pdf application/vnd.ms-word application/vnd.openxmlformats-officedocument.wordprocessingml.document application/x-hwp]
    unless allowed_types.include?(file.content_type)
      errors.add(:file, "은(는) PDF, HWP, DOCX 형식만 허용됩니다.")
    end
  end

  # ActiveStorage 파일 크기 검증
  def validate_file_size
    return unless file.attached?

    if file.blob.byte_size > 50.megabytes
      errors.add(:file, "크기는 50MB 이하여야 합니다.")
    end
  end

  # 파일 메타데이터 자동 설정
  def set_file_metadata
    return unless file.attached?

    self.filename = file.filename.to_s
    self.file_type = extract_file_type(file.filename.to_s)
    self.file_size = file.blob.byte_size
  end

  # 파일 확장자에서 파일 타입 추출
  def extract_file_type(filename)
    extension = File.extname(filename).delete_prefix(".").downcase
    case extension
    when "pdf" then "pdf"
    when "hwp" then "hwp"
    when "docx", "doc" then "docx"
    else "unknown"
    end
  end
end
