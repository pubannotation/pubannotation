class Modification < Annotation
  belongs_to :obj, polymorphic: true

  attr_accessible :hid, :pred

  def get_hash
    hmodification = Hash.new
    hmodification[:id] = hid
    hmodification[:pred] = pred
    hmodification[:obj] = obj.hid
    hmodification
  end
end
