package;

import haxe.Timer;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

import openfl.events.Event;
import openfl.display.Sprite;
import openfl.net.FileReference;
import openfl.utils.ByteArray;
import openfl.Lib;

import haxe.Int64;
import lime.utils.Assets;
import lime.utils.UInt8Array;
import lime.utils.Int16Array;
import lime.utils.Float32Array;
import lime.media.codecs.vorbis.VorbisFile;

/**
 * Just a bug when using fromBytes to read a OGG file in OpenFL
 */
class Main extends Sprite
{
  private static inline var STREAM_BUFFER_SIZE = 48000;

  var bytes:Bytes;
  var reader:VorbisFile;

  var length:Int;
  var channels:Int;
  var sampleRate:Int;

  public function new()
  {
    super();

    // Begin with FromFile
    testFromFile( function()
    {
      trace("FromFile complete!");

      // Wait a little bit then run bytes test
      var timer = new Timer(2000);
      timer.run = function()
      {
        timer.stop();
        testFromBytes( function()
        {
          trace("Everything is complete!!");
        } );
      };
    } );
  }

  function testFromFile( handler:Void->Void )
  {
    trace("Loading file...");

    reader = VorbisFile.fromFile("assets/test1.ogg");
    testOGG( handler );
  }

  function testFromBytes( handler:Void->Void )
  {
    trace("Loading bytes...");

    Assets.loadBytes("assets/test1.ogg").onComplete(function(bytes)
    {
      this.bytes = bytes; // Makes sure it is not GC
      reader = VorbisFile.fromBytes( bytes );

      testOGG( handler );
    });
  }

  function initWAV(output:BytesOutput)
  {
    var bitsPerSample = 16;
    var byteRate = Std.int(channels * sampleRate * bitsPerSample / 8);
    var blockAlign = Std.int(channels * bitsPerSample / 8);
    var dataLength = length * channels * 2;

    output.bigEndian = false;
    output.writeString("RIFF");
    output.writeInt32(36 + dataLength);
    output.writeString("WAVEfmt ");
    output.writeInt32(16);
    output.writeUInt16(1);
    output.writeUInt16(channels);
    output.writeInt32(sampleRate);
    output.writeInt32(byteRate);
    output.writeUInt16(blockAlign);
    output.writeUInt16(bitsPerSample);
    output.writeString("data");
    output.writeInt32(dataLength);
  }

  function readVorbisFileBuffer( length:Int )
  {
    var buffer = new Int16Array( Std.int(length / 2) );
    //var buffer = new Float32Array( length );

    var read = 0, total = 0, readMax;

    while ( total < length )
    {
      readMax = 4096;

      if ( readMax > (length - total) )
      {
        readMax = length - total;
      }

      // BUG #2 - FromBytes will crashes here after a few read but not always!
      read = reader.read( buffer.buffer, total, readMax );
      //read = reader.readFloat( buffer.buffer, readMax );

      trace("READ", read);

      if (read > 0)
      {
        total += read;
      }
      else
      {
        break;
      }
    }

    return buffer;
  }

  function testOGG( handler:Void->Void )
  {
    var info = reader.info();
    var output = new BytesOutput();

    length = Int64.toInt(reader.pcmTotal());
    channels = info.channels;
    sampleRate = info.rate;

    trace("Info", length, channels, sampleRate);

    // Prepare WAV
    initWAV(output);

    // Test Seek
    trace("Seekable", reader.seekable());

    // BUG #1 - FromBytes crashes here!
    reader.pcmSeek( Int64.ofInt(44100) ); // Test skipping 1 sec

    trace("Tell", reader.pcmTell());

    // Test Read
    var dataLength = Std.int( length * channels * 2 ); // 16 bits == 2 bytes

    var position = 0, buffer = null, stop = false, buffer = null;

    while ( !stop )
    {
      if ( (dataLength - position) >= STREAM_BUFFER_SIZE )
      {
        buffer = readVorbisFileBuffer(STREAM_BUFFER_SIZE);
        position += STREAM_BUFFER_SIZE;
      }
      else if ( position < dataLength )
      {
        buffer = readVorbisFileBuffer(dataLength - position);
        stop = true;
      }
      else
      {
        stop = true;
        break;
      }

      trace( "P", Int64.toInt( reader.pcmTell() ) );

      // Write to output
      for ( i in 0...buffer.length )
      {
        output.writeInt16( buffer[i] );
      }
    }

    // It's done!
    trace("Done!", Int64.toInt( reader.pcmTell() ));

    // Save WAV file for debug
    var fileRef:FileReference = new FileReference();
    fileRef.addEventListener( Event.SELECT, function(e)
    {
      reader.clear();
      handler();
    }, false, 0, true );

    fileRef.save(ByteArrayData.fromBytes(output.getBytes()), name);
  }
}
