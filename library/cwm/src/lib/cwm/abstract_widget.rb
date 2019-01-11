require "abstract_method"
require "yast"

Yast.import "UI"

module CWM
  # A Yast::Term that can be passed as is to Yast::UI methods
  # (OpenDialog, ReplaceWidget)
  #
  # The normal workflow is that a {WidgetTerm} becomes a {StringTerm}
  # which becomes a {UITerm}.
  class UITerm < Yast::Term; end

  # A Yast::Term that contains strings
  # which identify the old style hash based CWM widgets.
  # Can be passed to {Yast::CWMClass#ShowAndRun Yast::CWM.ShowAndRun}
  #
  # The normal workflow is that a {WidgetTerm} becomes a {StringTerm}
  # which becomes a {UITerm}.
  class StringTerm < Yast::Term; end

  # A Yast::Term that contains instances of {CWM::AbstractWidget}.
  # Can be passed to {Yast::CWMClass#show Yast::CWM.show}
  #
  # The normal workflow is that a {WidgetTerm} becomes a {StringTerm}
  # which becomes a {UITerm}.
  class WidgetTerm < Yast::Term; end

  # A {Hash{String=>Object}} that {Yast::CWMClass} knows to handle.
  # TODO: document the members
  class WidgetHash < Hash; end

  # Represent base for any widget used in CWM. It can be passed as "widget"
  # argument. For more details about usage
  # see {Yast::CWMClass#show Yast::CWM.show}
  #
  # Underneath there is a widget library with a procedural API, using symbol parameters as widget IDs.
  #
  # The call sequence is:
  #
  # - `#initialize` is called by the Ruby constructor {.new}
  # - CWM#show builds a widget tree, using
  #     - the AbstractWidget concrete class
  #     - {#opt} widget options: `[:notify]` is needed if {#handle} is defined
  #     - {#label}
  #     - {#help}
  #
  # - {#init} may initialize the widget state from persistent storage
  # - loop:
  #     - {#handle} may update other widgets if this one tells them to
  #     - {#validate} may decide whether the user input is valid
  # - {#store} may store the widget state to persistent storage
  class AbstractWidget
    include Yast::UIShortcuts
    include Yast::I18n
    include Yast::Logger

    # By default, {#handle} has no argument and it is called
    # only for events of its own widget.
    # If true, {#handle}(event) is called for events of any widget.
    # @return [Boolean]
    def handle_all_events
      @handle_all_events.nil? ? false : @handle_all_events
    end
    attr_writer :handle_all_events

    # @return [String] An ID, unique within a dialog, used for the widget.
    #   By default, the class name is used.
    def widget_id
      @widget_id || self.class.to_s
    end
    attr_writer :widget_id

    # Declare widget type for {Yast::CWMClass}.
    # Your derived widgets will not need to do this.
    # @param type [Symbol]
    # @return [void]
    def self.widget_type=(type)
      define_method(:widget_type) { type }
    end

    # The following methods are only documented but not defined
    # because we do not want to accidentally override the subtle defaults
    # used by Yast::CWMClass.

    # @!method help
    #   Called only once by default. Also triggered by {#refresh_help}.
    #   @return [String] translated help text for the widget

    # @!method label
    #   Derived classes must override this method to specify a label.
    #   @return [String] translated label text for the widget

    # @!method opt
    #   Specifies options passed to widget. When {handle} method is defined, it
    #   is often expected to be immediatelly notified from widget and for that
    #   purpose opt method with `[:notify]` as return value is needed.
    #   @return [Array<Symbol>] options passed to widget
    #     like `[:hstretch, :vstretch]`

    # @!method init
    #   Initialize the widget: set initial value
    #   @return [void]

    # @!method handle(*args)
    # @overload handle
    #   Process an event generated by this widget. This method is invoked
    #   if {#handle_all_events} is `false`.
    #   @note defining {handle} itself does not pass `:notify` to widget. It has
    #     to be done with {opt} method.
    #   @return [nil,Symbol] what to return from the dialog,
    #     or `nil` to continue processing
    # @overload handle(event)
    #   Process an event generated a widget. This method is invoked
    #   if {#handle_all_events} is `true`.
    #   @note defining {handle} itself does not pass `:notify` to widget. It has
    #     to be done with {opt} method.
    #   @param event [Hash] see CWMClass
    #   @return [nil,Symbol] what to return from the dialog,
    #     or `nil` to continue processing

    # @!method validate
    #   Validate widgets before ending the loop and storing.
    #   @return [Boolean] validate widget value.
    #     If it fails (`false`) the dialog will not return yet.

    # @!method store
    #   Store the widget value for further processing
    #   @return [void]

    # @!method cleanup
    #   Clean up after the widget is destroyed
    #   @return [void]

    # Generate widget definition for {Yast::CWMClass}.
    # It refers to
    # {#help}, {#label}, {#opt}
    # {#validate}, {#init}, {#handle}, {#store}, {#cleanup}.
    # @return [WidgetHash]
    # @raise [RuntimeError] if a required method is not implemented
    #   or widget_type is not set.
    def cwm_definition
      if !respond_to?(:widget_type)
        raise "Widget '#{self.class}' does set its widget type"
      end

      res = {}

      res["_cwm_key"] = widget_id
      if respond_to?(:help)
        res["help"] = help_method
      else
        res["no_help"] = ""
      end
      res["label"] = label if respond_to?(:label)
      res["opt"] = opt if respond_to?(:opt)
      if respond_to?(:validate)
        res["validate_function"] = validate_method
        res["validate_type"] = :function
      end
      res["handle_events"] = [widget_id] unless handle_all_events
      res["init"] = init_method if respond_to?(:init)
      res["handle"] = handle_method if respond_to?(:handle)
      res["store"] = store_method if respond_to?(:store)
      res["cleanup"] = cleanup_method if respond_to?(:cleanup)
      res["widget"] = widget_type

      res
    end

    # @return [Boolean] Is widget open for interaction?
    def enabled?
      Yast::UI.QueryWidget(Id(widget_id), :Enabled)
    end

    # Opens widget for interaction
    # @return [void]
    def enable
      Yast::UI.ChangeWidget(Id(widget_id), :Enabled, true)
    end

    # Closes widget for interaction
    # @return [void]
    def disable
      Yast::UI.ChangeWidget(Id(widget_id), :Enabled, false)
    end

    # Focus the widget. Useful when validation failed to highlight it.
    def focus
      Yast::UI.SetFocus(Id(widget_id))
    end

  protected

    # A helper to check if an event is invoked by this widget
    # @param event [Hash] a UI event
    def my_event?(event)
      widget_id == event["ID"]
    end

    # A widget will need to call this if its {#help} text has changed,to make the change effective.
    def refresh_help
      Yast.import "CWM"

      Yast::CWM.ReplaceWidgetHelp
    end

    # shortcut from Yast namespace to avoid including whole namespace
    # @todo kill converts in CWM module, to avoid this workaround for funrefs
    # @return [Yast::FunRef]
    def fun_ref(*args)
      Yast::FunRef.new(*args)
    end

  private

    # @note all methods here use wrappers to modify required parameters as CWM
    # have not so nice callbacks API
    def init_method
      fun_ref(method(:init_wrapper), "void (string)")
    end

    def init_wrapper(_widget_id)
      init
    end

    def handle_method
      fun_ref(method(:handle_wrapper), "symbol (string, map)")
    end

    def help_method
      fun_ref(method(:help), "string ()")
    end

    # allows both variant of handle. with event map and without.
    # with map it make sense when handle_all_events is true or in custom widgets
    # with multiple elements, that generate events, otherwise map is not needed
    def handle_wrapper(_widget_id, event)
      m = method(:handle)
      if m.arity == 0
        m.call
      else
        m.call(event)
      end
    end

    def store_method
      fun_ref(method(:store_wrapper), "void (string, map)")
    end

    def store_wrapper(_widget_id, _event)
      store
    end

    def cleanup_method
      fun_ref(method(:cleanup_wrapper), "void (string)")
    end

    def cleanup_wrapper(_widget_id)
      cleanup
    end

    def validate_method
      fun_ref(method(:validate_wrapper), "boolean (string, map)")
    end

    def validate_wrapper(_widget_id, _event)
      validate
    end
  end
end
