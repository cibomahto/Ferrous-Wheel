/**
 * Brightness Thresholding 
 * by Golan Levin. 
 *
 * GSVideo version by Andres Colubri. 
 * 
 * Determines whether a test location (such as the cursor) is contained within
 * the silhouette of a dark object. 
 */

import codeanticode.gsvideo.*;

import themidibus.*;

int windowHeight = 240;
int windowWidth = 320;

color black = color(0);
color white = color(255);

int numPixels;
GSCapture video;

// Start and end points for the detection line
int startX = 183;
int startY = 59;
int endX = 61;
int endY = 156;

int threshold = 122; // Set the threshold value

int lineData [ ]; // Data along the detection line

MidiBus myBus; // The MidiBus

// MIDI info
int midiRange = 24;      // Number of notes in the MIDI scale
int midiStart = 42;      // First note
int midiVelocity = 127;  // Velocity (change this based on blob size you say?)

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


void setup() {
  
  size(windowWidth, windowHeight);
  strokeWeight(5);
  // Uses the default video input, see the reference if this causes an error
  video = new GSCapture(this, width, height, 24);
  numPixels = video.width * video.height;
//  noCursor();
  smooth();
  
  myBus = new MidiBus(this, 0, 0); // Create a new MIDI device
  
    /**
    using-the-mousewheel-scrollwheel-in-processing taken from http://processinghacks.com/hacks:using-the-mousewheel-scrollwheel-in-processing
    @author Rick Companje
    */
    addMouseWheelListener(new java.awt.event.MouseWheelListener() { 
    public void mouseWheelMoved(java.awt.event.MouseWheelEvent evt) { 
      mouseWheel(evt.getWheelRotation());
    }});
}


void mouseWheel(int delta) {
  threshold += delta;
  println("threshold=" + threshold); 
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
  int channel = 0;
  int velocity = 127;
  
  if (video.available()) {
    video.read();
    video.loadPixels();
    float pixelBrightness; // Declare variable to store a pixel's color
    // Turn each pixel in the video frame black or white depending on its brightness
    loadPixels();
    for (int i = 0; i < numPixels; i++) {
      pixelBrightness = brightness(video.pixels[i]);
      if (pixelBrightness > threshold) { // If the pixel is brighter than the
        pixels[i] = white; // threshold value, make it white
      } 
      else { // Otherwise,
        pixels[i] = black; // make it black
      }
    }
    
    // get the current sense line
    getLine(startY, startX, endY, endX);

    
    for(int i = 0; i < lineData.length; i++) {
      pixels[i+1+windowWidth*(windowHeight - 4)] = lineData[i];
      pixels[i+1+windowWidth*(windowHeight - 3)] = lineData[i];
      pixels[i+1+windowWidth*(windowHeight - 2)] = lineData[i];
    }
    
    // Refresh the blob list by marking everything old and then searching for current/new ones
    for (Iterator it = blobList.iterator(); it.hasNext(); ) {
      blob currentBlob = (blob)it.next();
      
//      println("marking blob " + currentBlob.center + " invalid");
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
          if( found == false ) {
            int pitch = (int)(((float)center/lineData.length)*midiRange) + midiStart;
            
            blobList.add(new blob(center, width, pitch));

            myBus.sendNoteOn(channel, pitch, velocity); // Send a Midi noteOn
            
            println("Found new blob: center=" + center + " width=" + width + " pitch=" + pitch);
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
        println("removing invalid blob " + currentBlob.center);
        
        it.remove();        
       
        myBus.sendNoteOff(channel, currentBlob.pitch, velocity); // Send a Midi nodeOff
      }
    }

   
//    myBus.sendNoteOn(channel, pitch, velocity); // Send a Midi noteOn
//    delay(200);
//    myBus.sendNoteOff(channel, pitch, velocity); // Send a Midi nodeOff
  }
}

// Right-click to set start of line, left-click to set end
void mousePressed()
{
   if (mouseButton == LEFT) {
    startX = mouseX;
    startY = mouseY;
    println("startX=" + startX + " startY=" + startY);
  } else if (mouseButton == RIGHT) {
    endX = mouseX;
    endY = mouseY;
    println("nedX=" + endX + " endY=" + endY);
  }
}


  
  
