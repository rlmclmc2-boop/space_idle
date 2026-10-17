Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Private.Windows.GdiPlus,System.Private.Windows.Core -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;

public static class ArtGif {
    static PropertyItem Property(int id, short type, byte[] value) {
        var item = (PropertyItem)Activator.CreateInstance(typeof(PropertyItem), true);
        item.Id = id; item.Type = type; item.Len = value.Length; item.Value = value;
        return item;
    }
    static Bitmap Frame(string path) {
        using (var source = new Bitmap(path)) {
            var target = new Bitmap(480, 376);
            using (var g = Graphics.FromImage(target)) {
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                g.DrawImage(source, 0, 0, target.Width, target.Height);
            }
            return target;
        }
    }
    public static void Encode(string[] frames, string output, int delay) {
        ImageCodecInfo codec = null;
        foreach (var option in ImageCodecInfo.GetImageEncoders())
            if (option.MimeType == "image/gif") { codec = option; break; }
        if (codec == null) throw new Exception("GIF encoder unavailable");
        var delays = new byte[frames.Length*4];
        for (int i=0; i<frames.Length; i++) BitConverter.GetBytes(delay).CopyTo(delays,i*4);
        using (var first = Frame(frames[0])) {
            first.SetPropertyItem(Property(0x5100,4,delays));
            first.SetPropertyItem(Property(0x5101,3,new byte[]{0,0}));
            using (var parameters = new EncoderParameters(1)) {
                parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag,(long)EncoderValue.MultiFrame);
                first.Save(output,codec,parameters);
                for (int i=1; i<frames.Length; i++) {
                    using (var next = Frame(frames[i])) {
                        parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag,(long)EncoderValue.FrameDimensionTime);
                        first.SaveAdd(next,parameters);
                    }
                }
                parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag,(long)EncoderValue.Flush);
                first.SaveAdd(parameters);
            }
        }
    }
}
'@
$frames = @(Get-ChildItem 'docs/tasks/playtest-ui-art/evidence/animation' -Filter 'frame_*.png' | Sort-Object Name | ForEach-Object FullName)
if ($frames.Count -ne 36) { throw "Expected 36 original frames, found $($frames.Count)" }
$output = Join-Path (Get-Location) 'docs/tasks/playtest-ui-art/evidence/factory-research.gif'
[ArtGif]::Encode($frames,$output,10)
Get-Item $output | Select-Object FullName,Length
