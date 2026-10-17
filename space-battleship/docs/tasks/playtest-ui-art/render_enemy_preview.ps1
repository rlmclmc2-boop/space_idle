Add-Type -AssemblyName System.Drawing
$names = @('scout','sentry','interceptor','swarm','anchor','reactive','shielded','command')
$paths = @(
  'assets/ships/enemy/opening_v2/scout-hull.png',
  'assets/ships/enemy/opening_v2/sentry-hull.png',
  'assets/ships/enemy/opening_v2/interceptor-hull.png',
  'assets/ships/enemy/opening_v2/swarm-hull.png',
  'assets/ships/enemy/opening_v2/anchor-hull.png',
  'assets/ships/enemy/opening_v2/reactive-hull.png',
  'assets/ships/enemy/opening_v2/shielded-hull.png',
  'assets/ships/enemy/opening_v2/command-hull.png'
)
$output = 'docs/tasks/playtest-ui-art/evidence/enemy-native-scale.png'
New-Item -ItemType Directory -Force -Path (Split-Path $output) | Out-Null
$bitmap = [Drawing.Bitmap]::new(960,360)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([Drawing.Color]::FromArgb(14,37,52))
$font = [Drawing.Font]::new('Segoe UI',11)
$brush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(239,235,212))
try {
  for ($row=0; $row -lt 2; $row++) {
    $width = @(40,64)[$row]
    for ($i=0; $i -lt $names.Count; $i++) {
      $x = 14 + $i*118
      $y = 28 + $row*170
      $image = [Drawing.Image]::FromFile((Resolve-Path $paths[$i]))
      try { $graphics.DrawImage($image,[Drawing.Rectangle]::new($x+((64-$width)/2),$y,$width,$width*2)) }
      finally { $image.Dispose() }
      $graphics.DrawString("$($names[$i]) ${width}px",$font,$brush,[single]$x,[single]($y+132))
    }
  }
  $bitmap.Save((Join-Path (Get-Location) $output),[Drawing.Imaging.ImageFormat]::Png)
}
finally { $brush.Dispose(); $font.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
