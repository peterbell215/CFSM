require 'cfsm'

class TrafficLight < CFSM
  state :ns_green do
    on :move_forward do

    end
  end

  state :ns_yellow do

  end

  state :ns_red do

  end

  state :we_redyellow do

  end

  state :we_yellow do

  end

  state :we_green do

  end

  state :we_yellow do

  end

  state :we_red do

  end
end