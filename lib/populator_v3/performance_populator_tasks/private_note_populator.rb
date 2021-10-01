class PrivateNotePopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    ref_obj_ids = @program.connection_memberships.pluck(:id)
    private_notes_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, ref_obj_ids)
    process_patch(ref_obj_ids, private_notes_hsh) 
  end

  def add_private_notes(ref_obj_ids, count, options = {})
    self.class.benchmark_wrapper "private_notes" do
      temp_ref_obj_ids = ref_obj_ids * count    
      Connection::PrivateNote.populate(ref_obj_ids.size * count, :per_query => 5_000) do |private_note|
        private_note.ref_obj_id = temp_ref_obj_ids.shift
        private_note.text = Populator.sentences(4..6)
        self.dot
      end
      self.class.display_populated_count(ref_obj_ids.size * count, "private_notes")
    end
  end

  def remove_private_notes(ref_obj_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Private Notes................" do
      private_note_ids = Connection::PrivateNote.where(:ref_obj_id => ref_obj_ids).select([:id, :ref_obj_id]).group_by(&:ref_obj_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      Connection::PrivateNote.where(:id => private_note_ids).destroy_all
      self.class.display_deleted_count(ref_obj_ids.size * count, "private_notes")
    end
  end
end