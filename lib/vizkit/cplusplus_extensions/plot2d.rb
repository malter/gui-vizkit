#prepares the c++ qt widget for the use in ruby with widget_grid

Vizkit::UiLoader::extend_cplusplus_widget_class "Plot2d" do
    attr_accessor :options

    def default_options()
        options = Hash.new
        options[:auto_scrolling] = true     # auto scrolling for a specific axis is true
        options[:auto_scrolling_y] = false  # if one of auto_scrolling or auto_scrolling_<axis>
        options[:auto_scrolling_x] = false  # is true
        options[:time_window] = 30              #window size during auto scrolling
        options[:cached_time_window] = 60        #total cached window size
        options[:pre_time_window] = 5
        options[:xaxis_window] = 5
        options[:pre_xaxis_window] = 5
        options[:yaxis_window] = 5
        options[:pre_yaxis_window] = 5
        options[:max_points] = 50000
	
        options[:colors] = [Qt::red, Qt::green, Qt::blue, Qt::cyan, Qt::magenta, Qt::yellow, Qt::gray]
        options[:reuse] = true
        options[:use_y_axis2] = false
        options[:plot_style] = :Line  #:Dot
        options[:multi_use_menu] = true
        options[:update_period] = 0.25   # repaint periode if new data are available
                                         # this prevents repainting for each new sample
        return options 
    end

    def time 
        time = if @log_replay
                   @log_replay.time
               else
                   Time.now
               end
        @time ||= time 
        time
    end

    def setXTitle(value)
        getXAxis.setLabel(value.to_s)
    end

    def setYTitle(value)
        getYAxis.setLabel(value.to_s)
    end

    def initialize_vizkit_extension
        @options = default_options
        @graphs = Hash.new
        @time = nil 
        @timer = Qt::Timer.new
        @needs_update = false
        @timer.connect(SIGNAL"timeout()") do 
            replot if @needs_update
            @needs_update = false
        end
        @timer.start(1000*@options[:update_period])

        getLegend.setVisible(true)
        getXAxis.setLabel("Time in sec")
        setTitle("Rock-Plot2d")
        self.connect(SIGNAL('mousePress(QMouseEvent*)')) do |event|
            if event.button() == Qt::RightButton 
                #show pop up menue 
                menu = Qt::Menu.new(self)
                action_scrolling = Qt::Action.new("AutoScrolling", self)
                action_scrolling.checkable = true
                action_scrolling.checked = @options[:auto_scrolling]
                menu.add_action(action_scrolling)
                if @options[:multi_use_menu]
                    action_reuse = Qt::Action.new("Reuse Widget", self)
                    action_reuse.checkable = true
                    action_reuse.checked = @options[:reuse]
                    menu.add_action(action_reuse)
                    action_use_y2 = Qt::Action.new("Use 2. Y-Axis", self)
                    action_use_y2.checkable = true
                    action_use_y2.checked = @options[:use_y_axis2]
                    menu.add_action(action_use_y2)
		    action_plotdot = Qt::Action.new("'dot' style", self)
 		    action_plotdot.checkable = true
                    action_plotdot.checked = @options[:plot_style] == :Dot
                    menu.add_action(action_plotdot)
		    action_plotline = Qt::Action.new("'line' style", self)		    
 		    action_plotline.checkable = true
                    action_plotline.checked = @options[:plot_style] == :Line
                    menu.add_action(action_plotline)
                end
                menu.addSeparator
                action_saving = Qt::Action.new("Save to File", self)
                menu.add_action(action_saving)

                action = menu.exec(mapToGlobal(event.pos))
                if(action == action_scrolling)
                    @options[:auto_scrolling] = !@options[:auto_scrolling]
                    setZoomAble !@options[:auto_scrolling]
                    setRangeAble !@options[:auto_scrolling]
                elsif(action == action_reuse)
                    @options[:reuse] = !@options[:reuse]
                elsif(action == action_use_y2)
                    @options[:use_y_axis2] = !@options[:use_y_axis2]
 		elsif(action == action_plotdot)
                    plot_style(:Dot)
		elsif(action == action_plotline)
                    plot_style(:Line)
                elsif action == action_saving
                    file_path = Qt::FileDialog::getSaveFileName(nil,"Save Plot to Pdf",File.expand_path("."),"Pdf (*.pdf)")
                    savePdf(file_path,false,0,0) if file_path
                end
            end
        end
    end

    def graph_style(graph,style)
        if style == :Dot
            graph.setLineStyle(Qt::CPGraph::LSNone)
            graph.setScatterStyle(Qt::CPGraph::SSDot)
        else
            graph.setLineStyle(Qt::CPGraph::LSLine)
            graph.setScatterStyle(Qt::CPGraph::SSNone)
        end
        @needs_update = true
    end

    def plot_style(style)
        if @options[:plot_style] != style 
            @options[:plot_style] = style
            @graphs.each_value do |graph|
                graph_style(graph,style)
            end
        end
    end

    def config(value,options)
        @log_replay = if value.respond_to? :task
                          if value.task.respond_to? :log_replay
                              value.task.log_replay
                          end
                      end
        @options = options.merge(@options)
        if value.type_name == "/base/samples/SonarBeam"
            if !@graphs.empty?
                puts "Cannot plot SonarBeam because plot is already used!"
                return :do_not_connect
            else
                @options[:multi_use_menu] = false
                getXAxis.setLabel "Bin Number"
            end
        elsif value.type_name =~ /\/std\/vector</ || value.type_name == "/base/samples/LaserScan"
            if !@graphs.empty?
                puts "Cannot plot std::vector because plot is already used!"
                return :do_not_connect
            else
                @options[:multi_use_menu] = false
                getXAxis.setLabel "Index"
            end
        end
        subfield = Array(options[:subfield]).join(".")
        subfield = "." + subfield if !subfield.empty?
        graph2(value.full_name+subfield) if value.respond_to? :full_name
    end

    def graph2(name)	
        graph = if(@graphs.has_key?(name))	            
                    @graphs[name]		    
                else    		    
                    graph = if @options[:use_y_axis2] == true
                                getYAxis2.setVisible(true)
                                getYAxis2.setLabel(name.split(".").last)
                                org = $VERBOSE
                                $VERBOSE = nil
                                graph = addGraph(getXAxis(),getYAxis2())
                                $VERBOSE = org 
                                graph
                            else
                                getYAxis.setLabel(name.split(".").last)                                
                                org = $VERBOSE
                                $VERBOSE = nil
                                graph = addGraph(getXAxis(),getYAxis())						
                                $VERBOSE = org 
                                graph
                            end

                    graph.setName(name)
                    graph_style(graph,@options[:plot_style])
                    graph.addToLegend
                    if(@graphs.size < @options[:colors].size)
                        graph.setPen(Qt::Pen.new(Qt::Brush.new(@options[:colors][@graphs.size]),1))
                    end
                    @graphs[name] = graph
                end
    end

    def multi_value?
        @options[:reuse] && @options[:multi_use_menu] 
    end

    def rename_graph(old_name,new_name)
        graph = @graphs[old_name]
        if graph           
            graph.setName(new_name)
            @graphs[new_name] = @graphs[old_name]
            @graphs.delete old_name
        end
    end

    #diplay is called each time new data are available on the orocos output port
    #this functions translates the orocos data struct to the widget specific format
    def update(sample,name)        
        graph = graph2(name)
        x = time.to_f-@time.to_f
        graph.removeDataBefore(x-@options[:cached_time_window])
        graph.addData(x,sample.to_f)
        if @options[:auto_scrolling] || @options[:auto_scrolling_x]
            getXAxis.setRange(x-@options[:time_window],x+@options[:pre_time_window])
            graph.rescaleValueAxis(true)
        end
        @needs_update = true
    end

    def update_orientation(sample,name)
        rename_graph(name,name+"_yaw")
        update(sample.yaw   *(180.00/Math::PI),name+"_yaw")
        update(sample.pitch *(180.00/Math::PI),name+"_pitch")
        update(sample.roll   *(180.00/Math::PI),name+"_roll")
    end

    def update_vector3d(sample,name)
        rename_graph(name,name+"_x")
        update(sample[0],name+"_x")
        update(sample[1],name+"_y")
        update(sample[2],name+"_z")
    end
    
    def update_vectorXd(sample,name)
        if (sample.size() == 1)
            update(sample[0], name)
        else
            rename_graph(name,name+"[0]")
            for i in (0..sample.size()-1)
                update(sample[i], name+"["+i.to_s()+"]")
            end
        end
    end
  
    def update_time(sample, name)
        update(sample.to_f, name)
    end
 
    def set_x_axis_scale(start,stop)
        getXAxis.setRange(start,stop)
    end 
    
    def set_y_axis_scale(start,stop)
        getYAxis.setRange(start,stop)
    end 

    def update_custom(name,values_x,values_y)
	graph = graph2(name)
	graph.addData(values_x,values_y)	
	if @options[:auto_scrolling] || @options[:auto_scrolling_x]
        	getXAxis.setRange(values_x-@options[:xaxis_window],values_x+@options[:pre_xaxis_window])
        	graph.rescaleValueAxis(true)		
        end       
	if @options[:auto_scrolling] || @options[:auto_scrolling_y]
		getYAxis.setRange(values_y-@options[:yaxis_window],values_y+@options[:pre_yaxis_window])
        	graph.rescaleValueAxis(true)		
        end       
        @needs_update = true
    end

    def update_vector(sample,name)
        if sample.size() > @options[:max_points]
            Vizkit.logger.warn "Cannot plot #{name}. Vector is too big"
            return
        end
        graph = graph2(name)
        graph.clearData
        sample.to_a.each_with_index do |value,index|
            graph.addData(index,value)
        end
        if @options[:auto_scrolling] || @options[:auto_scrolling_x]
            graph.rescaleKeyAxis(false)
        end
        if @options[:auto_scrolling] || @options[:auto_scrolling_y]
            graph.rescaleValueAxis(false)
        end
        @needs_update = true
    end

    def update_sonar_beam(sample,name)
        update_vector sample.beam,name
    end
    def update_laser_scan(sample,name)
        update_vector sample.ranges,name
    end
    def update_angle(sample,name)
        update sample.rad,name
    end
end
vector_types = ["/std/vector</uint8_t>","/std/vector</uint16_t>","/std/vector</uint32_t>",
                "/std/vector</uint64_t>","/std/vector</int8_t>","/std/vector</int16_t>",
                "/std/vector</int32_t>","/std/vector</int64_t>","/std/vector</float>",
                "/std/vector</double>"]
Vizkit::UiLoader.register_widget_for("Plot2d","Typelib::NumericType",:update)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/Quaterniond",:update_orientation)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/samples/SonarBeam",:update_sonar_beam)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/samples/LaserScan",:update_laser_scan)
Vizkit::UiLoader.register_widget_for("Plot2d",vector_types,:update_vector)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/Angle",:update_angle)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/Vector3d",:update_vector3d)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/VectorXd",:update_vectorXd)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/Time",:update_time)
