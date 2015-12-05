require 'tk'

$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/../lib")

require 'cfsm'

class TrafficLightGraphic
  ROAD_Y = 250
  CANVAS_SIZE_X = 600
  CANVAS_SIZE_Y = 400
  LEFT_TRAFFIC_CENTRE = 50
  RIGHT_TRAFFIC_CENTRE = CANVAS_SIZE_Y - LEFT_TRAFFIC_CENTRE
  TRAFFIC_LIGHT_HEIGHT = 100
  TRAFFIC_WIDTH = 26
  LIGHT_HEIGHT = TRAFFIC_LIGHT_HEIGHT/2/3

  def initialize
    @light = { :left => {}, :right => {} }
    @root = TkRoot.new { title 'Traffic Lights' }

    @canvas = TkCanvas.new(@root) { background 'white' }

    TkcLine.new(@canvas, 0, ROAD_Y, CANVAS_SIZE_X, ROAD_Y) # Road

    draw_traffic_light(:left)
    draw_traffic_light(:right)

    @canvas.pack
  end

  def draw_traffic_light(light)
    traffic_light_centre = light==:left ? LEFT_TRAFFIC_CENTRE : RIGHT_TRAFFIC_CENTRE
    TkcLine.new(@canvas, traffic_light_centre, ROAD_Y, traffic_light_centre, ROAD_Y - TRAFFIC_LIGHT_HEIGHT/2)
    TkcRectangle.new(@canvas, traffic_light_centre - TRAFFIC_WIDTH/2,
                     ROAD_Y - TRAFFIC_LIGHT_HEIGHT/2,
                     traffic_light_centre + TRAFFIC_WIDTH/2,
                     ROAD_Y - TRAFFIC_LIGHT_HEIGHT)

    y_pos = ROAD_Y - TRAFFIC_LIGHT_HEIGHT/2
    [:green, :yellow, :red].each do |light|
      @light[light] = TkcOval.new(@canvas, traffic_light_centre - LIGHT_HEIGHT/2, y_pos,
                                  traffic_light_centre + LIGHT_HEIGHT/2, y_pos - LIGHT_HEIGHT)
      y_pos -= LIGHT_HEIGHT
    end
  end

  def set_traffic_light(left_or_right, lamp_on)
    @light[left_or_right].each_pair do |lamp, oval|
      oval[:fill] = ( lamp==lamp_on || lamp_on==:red_yellow && lamp != :green ) ?  lamp.to_s : 'white'
    end
  end

  def mainloop
    Tk.mainloop
  end
end

class TrafficLight < CFSM
  def initialize( name, traffic_light_graphic )
    super(name)
    @traffic_light_graphic = traffic_light_graphic
  end

  attr_reader :traffic_light_graphic

  state :red do
    on :other_been_red_for_10s, :if => 'src!=@name', :transition => :red_yellow do |e|
      traffic_light_graphic.set_traffic_light( self.name, e.event_class )
      CFSM.post( CfsmEvent.new :next_phase, :src => self.name, :delay => 2 )
      true
    end
  end

  state :red_yellow do
    on :next_phase, :if => 'src==@name', :transition => :green  do
      traffic_light_graphic.set_traffic_light( self.name, e.event_class )
      CFSM.post( CfsmEvent.new :next_phase, :src => self.name, :delay => 2 )
      true
    end
  end

  state :green do
    on :next_phase, :if => 'src==@name', :transition => :yellow  do
      traffic_light_graphic.set_traffic_light( self.name, e.event_class )
      CFSM.post( CfsmEvent.new :next_phase, :src => self.name, :delay => 30 )
      true
    end
  end

  state :yellow do
    on :next_phase, :if => 'src==@name', :transition => :red  do
      traffic_light_graphic.set_traffic_light( self.name, e.event_class )
      CFSM.post( CfsmEvent.new :other_been_red_for_10s, :src => self.name, :delay => 10 )
      true
    end
  end
end

traffic_light_graphic = TrafficLightGraphic.new

left = TrafficLight.new( :left, traffic_light_graphic)
right = TrafficLight.new( :right, traffic_light_graphic)
CFSM.start
CFSM.post( CfsmEvent.new :other_been_red_for_10s, :src => :left )


traffic_light_graphic.mainloop