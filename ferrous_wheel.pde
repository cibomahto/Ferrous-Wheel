/**
 * Ferrous Wheel
 * By Matt Mets
 * Sponsored by the Children's Museum of Pittsburgh 
 */

// Libraries
import codeanticode.gsvideo.*;    // GSVideo for motion capture
import themidibus.*;              // MIDI Bus for output
import proxml.*;                  // XML settings file

// Constants
int windowHeight = 240;
int windowWidth = 320;

color black = color(0);
color white = color(255);

int numPixels;

// Configuration options

// White balance correction factors for red and blue channels
// determine experimentally by measuring distance from green 
float redCorrection = .88;
float blueCorrection = 1.13;

int threshold = 104;      // Set the brightness threshold value

// Start and end points for the detection line
int startX = 195;
int startY = 87;
int endX = 83;
int endY = 137;

// MIDI info
int midiChannel = 0;      // MIDI channel to play notes on
int midiVelocity = 127;   // Velocity (change this based on blob size you say?)

int maxNotes = 9;     // Max # of notes allowed (don't overload the synth) (not implemented correctly)

// Use a pentatonic scale
int midiNotes[] = {42, 44, 46, 49, 51,
                   54, 56, 58, 61, 63,
                   66, 68 };


// Global objects
GSCapture video;          // The video source
MidiBus myBus;            // MIDI output device

int lineData [ ];         // Data along the detection line

String logFileName;       // Name of the log file

java.util.List blobList = new LinkedList();


// Representation of a found magnet
class blob {
  public blob(int center_, int width_, int pitch_) {
    center = center_;
    width = width_;
    pitch = pitch_;
    current = true;
  }
  int center;
  int width;
  int pitch;
  boolean current;
}


// Log a message to both the console and a file
void log(String message) {
  println(message);
  
  try {
    FileWriter file = new FileWriter(logFileName, true);
    file.write(millis() + " " + message + "\n");
    file.close();
  }
  catch (Exception e) {
    println("Error opening log file!");
  }
}


// If possible, read in the settings file.
void readSettings(){
  proxml.XMLInOut xmlInOut = new XMLInOut(this);
  
   try{
     xmlInOut.loadElement("settings.xml"); 
   }catch(Exception e){
     log("LOAD_SETTINGS_FAIL text=\"" + e + "\"");
   }
}


// Stupid xml callback, launched by readSettings()
void xmlEvent(proxml.XMLElement _x) {
  proxml.XMLElement settings = _x;
  proxml.XMLElement setting;

  for(int i = 0; i < settings.countChildren();i++){
    setting = settings.getChild(i);
    
    if( setting.getElement().equals("sense_line")) {
      startX = setting.getIntAttribute("startX");
      startY = setting.getIntAttribute("startY");
      endX = setting.getIntAttribute("endX");
      endY = setting.getIntAttribute("endY");      
      log("LOAD_SETTINGS startX=" + startX + " startY=" + startY + " endX=" + endX + " endY=" + endY);
    }
    else if( setting.getElement().equals("thresholding")) {
      threshold = setting.getIntAttribute("threshold");
      blueCorrection = setting.getFloatAttribute("blueCorrection");
      redCorrection = setting.getFloatAttribute("redCorrection");
      log("LOAD_SETTINGS threshold=" + threshold + " blueCorrection=" + blueCorrection + " redCorrection=" + redCorrection);
    }
  }
}


// Write out the settings file based on the global variables
void writeSettings(){
  // xml element to store and load the configuration settings
  proxml.XMLElement settings = new proxml.XMLElement("settings");
  proxml.XMLInOut xmlInOut = new XMLInOut(this);
  
  // Sense line: Where to look in the image
  proxml.XMLElement sense_line = new proxml.XMLElement("sense_line");
  sense_line.addAttribute("startX", startX);
  sense_line.addAttribute("startY", startY);
  sense_line.addAttribute("endX", endX);
  sense_line.addAttribute("endY", endY);
  settings.addChild(sense_line);

  // Thresholding: How to interpret brightness levels
  proxml.XMLElement thresholding = new proxml.XMLElement("thresholding");
  thresholding.addAttribute("threshold", threshold);
  thresholding.addAttribute("redCorrection", redCorrection);
  thresholding.addAttribute("blueCorrection", blueCorrection);
  settings.addChild(thresholding);
  
  xmlInOut.saveElement(settings,"settings.xml");
}


void setup() {
  // Construct a name for the current log file
  logFileName = "/home/ferrous/Desktop/logs/"
                + year() + "." + month() + "." + day()
                + "." +hour() + ":" + minute() + ".txt";
  
  log("START date=" + year() + "/" + month() + "/" + day()
      + " time=" + hour() + ":" + minute() + ":" + second());

  // Set up the window
  size(windowWidth, windowHeight);
  strokeWeight(5);
  
  // Try to load the settings file
  readSettings();
  
  // Uses the default video input, see the reference if this causes an error
  // For the installation, the on-board camera is disabled in the BIOS so it can't
  // get in the way.
  video = new GSCapture(this, width, height, 24);
  
  // Calculate the total number of pixels on the screen
  numPixels = video.width * video.height;

  // Choose the first MIDI device that is available
  // This isn't 'right' but it should work as long as VirMIDI shows up first in the list.
  String midiDevice = MidiBus.availableInputs()[0];
  log("MIDI device=\"" + midiDevice + "\"");
  
  myBus = new MidiBus(this, midiDevice, midiDevice); // Create a new MIDI device  
  
  //  using-the-mousewheel-scrollwheel-in-processing taken from:
  //  http://processinghacks.com/hacks:using-the-mousewheel-scrollwheel-in-processing
  //  @author Rick Companje
  addMouseWheelListener(new java.awt.event.MouseWheelListener() { 
  public void mouseWheelMoved(java.awt.event.MouseWheelEvent evt) { 
    mouseWheel(evt.getWheelRotation());
  }});
}


// http://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
void getLine(int x0, int y0, int x1, int y1) {
   int Dx = x1 - x0; 
   int Dy = y1 - y0;
   boolean steep = (abs(Dy) >= abs(Dx));
   if (steep) {
       int temp = x0;
       x0 = y0;
       y0 = temp;
       
       temp = x1;
       x1 = y1;
       y1 = temp;
       
       // recompute Dx, Dy after swap
       Dx = x1 - x0;
       Dy = y1 - y0;
   }
   int xstep = 1;
   if (Dx < 0) {
       xstep = -1;
       Dx = -Dx;
   }
   int ystep = 1;
   if (Dy < 0) {
       ystep = -1;		
       Dy = -Dy; 
   }
   int TwoDy = 2*Dy; 
   int TwoDyTwoDx = TwoDy - 2*Dx; // 2*Dy - 2*Dx
   int E = TwoDy - Dx; //2*Dy - Dx
   int y = y0;
   int xDraw, yDraw;
   
   lineData = new int [ abs(x1 - x0)];
   
   int n = 0;
   for (int x = x0; x != x1; x += xstep) {	
       if (steep) {			
           xDraw = y;
           yDraw = x;
       } else {			
           xDraw = x;
           yDraw = y;
       }
       // plot
       lineData[n] = pixels[xDraw*windowWidth + yDraw];
//       pixels[xDraw*windowWidth + yDraw] = color(127);
       pixels[xDraw*windowWidth + yDraw] = color(255,0,0);
       
       // next
       if (E > 0) {
           E += TwoDyTwoDx; //E += 2*Dy - 2*Dx;
           y = y + ystep;
       } else {
           E += TwoDy; //E += 2*Dy;
       }
       
       n++;
   }
}

void draw() {
 try {
  if (video.available()) {
    
    video.read();        // Grab a frame of video
    image(video,0,0);    // Copy the video to the display screen

    // Load the pixel array
    loadPixels();
    
    // Grab the current sense line out of the image
    getLine(startY, startX, endY, endX);

    // Look for colored magnets and black ledger lines
    for (int i = 0; i < lineData.length; i++) {
      
      // Grab the color data
      color pix = lineData[i];
      float p_red = red(pix)*redCorrection;
      float p_green = green(pix);      
      float p_blue = blue(pix)*blueCorrection;
      
      // Look for things that have color and might be a magnet
      // We define that as having a difference between any two channels (red, green or blue)
      // greater than a set threshold.  This was designed as a first-pass filter against noisy
      // pixel data, but a better approach would be to average larger areas and then operate on that.
      if( ( abs(p_red - p_green) > threshold ||
            abs(p_red - p_blue) > threshold ||
            abs(p_green - p_blue) > threshold ) 
          && (brightness(pix) > 10)
          && (brightness(pix) < 245))
      {
        lineData[i] = white;
      }
      else {
        lineData[i] = black;
      }
      
      // Look for things that might be the black ledger line
      // Just look for something that is sufficiently dark.
      if( brightness(pix) < 30) {
        lineData[i] = color(255,0,0);
      }
    }

    // Draw the thresholded line at the bottom of the screen, just for visual identification.
    for(int i = 0; i < lineData.length; i++) {
      pixels[i+1+windowWidth*(windowHeight - 4)] = lineData[i];
      pixels[i+1+windowWidth*(windowHeight - 3)] = lineData[i];
      pixels[i+1+windowWidth*(windowHeight - 2)] = lineData[i];
    }
    
    // Refresh the blob list by marking everything old and then searching for current/new ones
    for (Iterator it = blobList.iterator(); it.hasNext(); ) {
      blob currentBlob = (blob)it.next();
      currentBlob.current = false;
    }


    // Now, find the center of each block of darkness, and use that as a MIDI note:
    int noteStart = 0;
    boolean counting = false;
    for(int i = 0; i < lineData.length; i++) {
      if (counting && lineData[i] == white) {
        // Done counting
        counting = false;
        int center = (i - noteStart)/2 + noteStart;
        int width = i - noteStart;
        
        if (width > 2) { 
         
          boolean found = false;
          
          // If blob part of list, mark it current.
          for (Iterator it = blobList.iterator(); it.hasNext(); ) {
            blob currentBlob = (blob)it.next();
            if( abs(currentBlob.center - center) <= 2 ) {
              currentBlob.current = true;
              found = true;
            }
          }
          
          // Otherwise, add it to the list.
          if( found == false) {
            
            // Limit the max number of notes in flight to 9
            if ( blobList.size() > maxNotes ) {
              log("DROPPED_NOTE center=" + center + " width=" + width);
            }
            else {
              int pitch = midiNotes[(int)(((float)center/lineData.length)*midiNotes.length)];
              
              blobList.add(new blob(center, width, pitch));
              myBus.sendNoteOn(midiChannel, pitch, midiVelocity); // Send a Midi noteOn            
              log("NOTE_ON center=" + center + " width=" + width + " pitch=" + pitch);
            }
          }

        }
        
      }
      else if (!counting && lineData[i] == black) {
        // Start counting
        counting = true;
        noteStart = i;
      }
    }

    updatePixels(); 

    // Search through the list of known blobs, and remove ones that have disappeared
    for (Iterator it = blobList.iterator(); it.hasNext(); ) {
      blob currentBlob = (blob)it.next();
      
      if( currentBlob.current == false ) {
        log("NOTE_OFF center=" + currentBlob.center + " width=" + currentBlob.width + " pitch=" + currentBlob.pitch);
        
        it.remove();        
       
        myBus.sendNoteOff(midiChannel, currentBlob.pitch, midiVelocity); // Send a Midi nodeOff
      }
    }
  }
 }
 catch (Exception e)
 {
   log("EXCEPTION text=\"" + e + "\"");
 }
}

// Right-click to set start of line, left-click to set end
void mousePressed()
{
   if (mouseButton == LEFT) {
    startX = mouseX;
    startY = mouseY;
    log("UPDATE_SETTINGS startX=" + startX + " startY=" + startY);
    writeSettings();
  } else if (mouseButton == RIGHT) {
    endX = mouseX;
    endY = mouseY;
    log("UPDAT_SETTINGS endX=" + endX + " endY=" + endY);
    writeSettings();
  }
}


// Update the brighness threshold when the mouse wheel is spun
void mouseWheel(int delta) {
  threshold += delta;
  log("UPDATE_SETTINGS threshold=" + threshold);
  writeSettings();
}
