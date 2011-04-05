module Exceptions
  class B2thagError < StandardError; end
  class SkipContactError < B2thagError; end
  class AddPhotoError < B2thagError; end
  class GetAllContactsError < B2thagError; end
  class GetContactGroupsError < B2thagError; end
  class DeleteGroupsError < B2thagError; end
  class DeleteAllB2thagContactsError < B2thagError; end
  class AddGroupError < B2thagError; end
  class AddContactError < B2thagError; end
end