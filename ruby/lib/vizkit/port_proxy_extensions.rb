module Orocos
    extend_task 'port_proxy::Task' do
        #returns the Output-/InputPort of the proxy which writes/reads the data from/to the given port
        #raises an exception if the proxy is unable to proxy the given port 
        def proxy_port(port,options=Hash.new)
            port = port.to_orocos_port
            options, policy = Kernel.filter_options options,
                :periodicity => nil,
                :keep_last_value => false

            if !reachable? 
                raise "Task #{name}: is not reachable. Cannot proxy connection #{port.full_name}"
            end

            full_name = "#{port.task.name}_#{port.name}"
            if !has_port?("in_"+full_name)
                load_plugins_for_type(port.orocos_type_name)
                if !createProxyConnection(full_name,port.orocos_type_name,options[:periodicity],policy[:init] || options[:keep_last_value])
                    raise "Task #{name}: Cannot generate proxy ports for #{full_name}"
                end
                Orocos.info "Task #{name}: Create port_proxy ports: in_#{full_name} and out_#{full_name}."
            end

            port_in = self.port("in_"+full_name)
            port_out = self.port("out_"+full_name)
            if  port_in.orocos_type_name != port.orocos_type_name
                raise "Task #{name} cannot proxy port #{name} because the already existing proxy port has a different type!"
            end

            #we do not have to connect the ports if there is already a connection
            #all instances are using the same hash because only one proxy per ruby instance is allowed
            @@proxy_name ||= self.name
            raise "Cannot handle multiple PortProxies from the same ruby instance!" if @@proxy_name != self.name
            @@ports ||= Hash.new
            if @@ports.has_key?(port.full_name) && @@ports[port.full_name].task.reachable?
                if port.is_a? Orocos::OutputPort
                    port_out
                else
                    port_in
                end
            else
                @@ports[port.full_name] = port
                if port.respond_to? :reader
                    port.connect_to port_in, policy
                    Orocos.info "Task #{name}: Connecting #{port.full_name} with #{port_in.full_name}, policy=#{policy}"
                    port_out
                else
                    port_out.connect_to port, policy
                    Orocos.info "Task #{name}: Connecting #{port_out.full_name} with #{port.full_name}, policy=#{policy}"
                    port_in
                end
            end
        end

        def tooling?
            true
        end

        def port(name,options=Hash.new)
            port = super 
            #prevents that the proxy is proxyied by an other proxy task
            def port.force_local?
                true
            end
            port
        end

        #loads the plugins (typekit,transport) into the proxy
        def load_plugins_for_type(type_name)
            name = Orocos::find_typekit_for(type_name)
            plugins = Orocos::plugin_libs_for_name(name)
            plugins.each do |kit|
                Orocos.info "Task #{self.name}: trying to load plugin #{kit}"
                if !loadTypekit(kit)
                    Orocos.warn "Task #{self.name} cannot load plugin #{kit}! Is the task running on another machine?"
                    return nil
                end
            end
            true
        rescue Interrupt
            raise
        rescue Exception => e
            Orocos.warn "failed to load plugins for #{type_name} on #{name}: #{e}"
            e.backtrace.each do |line|
                Orocos.warn "  #{line}"
            end
            return nil
        end

        #returns true if the proxy is proxing the given port
        #returns false if the proxy is not proxing the given port or if the connection
        #between the proxy and the given port died
        def proxy_port?(port)
            return false if !reachable? 
            return false if !has_port?("in_#{port.task.name}_#{port.name}")
            if !@@ports.has_key?(port.full_name)
                Vizkit.Warn "Task #{self.name} is managed by an other ruby instance!"
                false
            end
            return false if !@@ports[port.full_name].task.reachable?
            true
        end
    end
end
