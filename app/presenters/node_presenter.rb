class NodePresenter
  delegate :outcome?, to: :@node

  def initialize(node, state = nil, _options = {}, _params = {})
    @node = node
    @state = state || SmartAnswer::State.new(nil)
  end
end
