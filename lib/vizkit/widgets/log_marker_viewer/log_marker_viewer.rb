# Main Window setting up the ui
class LogMarkerViewer < Qt::Widget 
  def initialize(parent = nil)
    super
    @logger = nil
    @layout = Qt::GridLayout.new
    @widget = Vizkit.load File.join(File.dirname(__FILE__),'log_marker_viewer.ui'), self
    @layout.addWidget(@widget,0,0)
    @current_index = -1;
    self.setLayout @layout
    resize(450,200)

    @widget.list.connect SIGNAL("itemDoubleClicked(QListWidgetItem*)") do |item|
        specs =  Vizkit.default_loader.find_all_plugin_specs(:argument => Orocos::Log::Replay,:callback_type => :control,:flags => {:deprecated => false})
        specs.each do |spec|
            plugin = spec.created_plugins.find do |plugin|
                plugin.respond_to?(:seek_to)
            end
            if plugin
                # set current index to clicked marker
                marker = @markers[@widget.list.current_row]
                plugin.seek_to(marker.time)
                # set end and start marker if clicked marker is a start
                # marker and the corresponding stop marker can be found
                break unless marker.type == :start
                @widget.list.current_row.upto(@markers.size-1) do |idx|
                    if @markers[idx].type == :stop && @markers[idx].index == marker.index
                        plugin.timeline_marker(marker.time,@markers[idx].time)
                        break
                    end
                end
                break
            end
        end
    end
  end

  def config2(markers)
      @markers = markers
      markers.each do |marker|
          if marker.index >= 0
              @widget.list.addItem("#{marker.time.to_s}: #{" "*3*marker.index}#{marker.type}(#{marker.index}): #{marker.comment}")
          else
              @widget.list.addItem("#{marker.time.to_s}: # #{marker.type}: #{marker.comment} #")
          end
      end
  end

  def config(annotations,options=Hash.new)
      config2(Orocos::Log::LogMarker.parse(annotations.samples))
  end
end

Vizkit::UiLoader.register_ruby_widget "LogMarkerViewer", LogMarkerViewer.method(:new)
Vizkit::UiLoader.register_widget_for "LogMarkerViewer", Orocos::Log::Annotations, :config
