/**
 * Ferrous Wheel
 * By Matt Mets
 * Sponsored by the Children's Museum of Pittsburgh 
 */

// Libraries
import codeanticode.gsvideo.*;    // GSVideo for motion capture
import themidibus.*;              // MIDI Bus for output

// Constants
int windowHeight = 240;
int windowWidth = 320;

color black = color(0);
color white = color(255);

int numPixels;

// Configuration options

// Start and end points for the detection line
int startX = 169;
int startY = 64;
int endX = 59;
int endY = 120;

int threshold = 104;      // Set the threshold value

// MIDI info
int midiChannel = 0;      // MIDI channel to play notes on
int midiRange = 13;       // Number of notes in the MIDI scale
int midiStart = 42;       // First note
int midiVelocity = 127;   // Velocity (change this based on blob size you say?)

int maxNotes = 9;     // Max # of notes allowed (don't overload the synth) (not implemented correctly)

// Global objects
GSCapture video;          // The video source
MidiBus myBus;            // MIDI output device

int lineData [ ];         // Data along the detection line

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

java.util.List blobList = new LinkedList();


// Log a message to both the console and a file
void log(String message) {
  println(message);
  
  try {
    FileWriter file = new FileWriter("/home/ferrous/Desktop/log.txt", true);
    file.write(millis() + " " + message + "\n");
    file.close();
  }
  catch (Exception e) {
    println("error opening log file!");
  }
}


void setup() {
  log("STARTUP date=" + year() + "/" + month() + "/" + day() + " time=" + hour() + ":" + minute() + ":" + second());

  size(windowWidth, windowHeight);
  strokeWeight(5);
  
  // Uses the default video input, see the reference if this causes an error
  // For the installation, the on-board camera is disabled in the BIOS so it can't
  // get in the way.
  video = new GSCapture(this, width, height, 24);

  // Dunno!
  smooth();
  
  // Calculate the total number of pixels on the screen
  numPixels = video.width * video.height;
  
//  MidiBus.list();
  
//  myBus = new MidiBus(this, 20, 20); // Create a new MIDI device
  myBus = new MidiBus(this, "VirMIDI [hw:1,0]", "VirMIDI [hw:1,0]"); // Create a new MIDI device  
    /**
      using-the-mousewheel-scrollwheel-in-processing taken from:
      http://processinghacks.com/hacks:using-the-mousewheel-scrollwheel-in-processing
      @author Rick Companje
    */
    addMouseWheelListener(new java.awt.event.MouseWheelListener() { 
    public void mouseWheelMoved(java.awt.event.MouseWheelEvent evt) { 
      mouseWheel(evt.getWheelRotation());
    }});
}


void mouseWheel(int delta) {
  threshold += delta;
  log("THRESHOLD_UPDATE threshold=" + threshold); 
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
       pixels[xDraw*windowWidth + yDraw] = color(127);

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
    video.read();
    video.loadPixels();
    float pixelBrightness; // Declare variable to store a pixel's color
    // Turn each pixel in the video frame black or white depending on its brightness
    loadPixels();

    for(int i = 0; i < numPixels; i++) {
      pixels[i] = video.pixels[i];
    }
          
//      pixelBrightness = brightness(video.pixels[i]);
//      if (pixelBrightness > threshold) { // If the pixel is brighter than the
//        pixels[i] = white; // threshold value, make it white
//      } 
//      else { // Otherwise,
//        pixels[i] = black; // make it black
//      }

    
    // get the current sense line
    getLine(startY, startX, endY, endX);

    // DO thresholding on the current line only
    for (int i = 0; i < lineData.length; i++) {
      color pix = lineData[i];
      
      float p_red = red(pix);
      float p_green = green(pix);      
      float p_blue = blue(pix);
      
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
    }
    
    for(int i = 0; i < lineData.length; i++) {
      pixels[i+1+windowWidth*(windowHeight - 4)] = lineData[i];
      pixels[i+1+windowWidth*(windowHeight - 3)] = lineData[i];
      pixels[i+1+windowWidth*(windowHeight - 2)] = lineData[i];
    }
    
    // Refresh the blob list by marking everything old and then searching for current/new ones
    for (Iterator it = blobList.iterator(); it.hasNext(); ) {
      blob currentBlob = (blob)it.next();
      
//      log("marking blob " + currentBlob.center + " invalid");
      currentBlob.current =false;
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
              int pitch = (int)(((float)center/lineData.length)*midiRange) + midiStart;
            
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

    for (Iterator it = blobList.iterator(); it.hasNext(); ) {
      blob currentBlob = (blob)it.next();
      
      if( currentBlob.current == false ) {
        log("NOTE_OFF center=" + currentBlob.center + " width=" + currentBlob.width + " pitch=" + currentBlob.pitch);
        
        it.remove();        
       
        myBus.sendNoteOff(midiChannel, currentBlob.pitch, midiVelocity); // Send a Midi nodeOff
      }
    }

   
//    myBus.sendNoteOn(channel, pitch, velocity); // Send a Midi noteOn
//    delay(200);
//    myBus.sendNoteOff(channel, pitch, velocity); // Send a Midi nodeOff
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
    log("START_UPDATE x=" + startX + " y=" + startY);
  } else if (mouseButton == RIGHT) {
    endX = mouseX;
    endY = mouseY;
    log("END_UPDATE x=" + endX + " y=" + endY);
  }
}
