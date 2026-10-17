Add-Type -AssemblyName System.Drawing
$devices = @(
  @('ai-singularity-v2.png','AI singularity',402,159,480,450),
  @('weapon-accuracy-v2.png','Weapon accuracy',382,90,520,520),
  @('equipment-reinforcement-v2.png','Reinforcement',344,92,596,491),
  @('resource-refining-v2.png','Resource refining',374,89,536,530),
  @('fragment-condensation-v2.png','Fragment condenser',345,141,594,474),
  @('equipment-precision-v2.png','Equipment precision',335,63,614,515),
  @('uranium-extraction-v2.png','Uranium extraction',350,117,584,484),
  @('joint-integration-v2.png','Joint integration',315,142,654,460)
)
$output = 'docs/tasks/playtest-ui-art/evidence/factory-contact-preview.png'
New-Item -ItemType Directory -Force -Path (Split-Path $output) | Out-Null
$bitmap = [Drawing.Bitmap]::new(1728,520)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.Clear([Drawing.Color]::FromArgb(11,33,49))
$backdrop = [Drawing.Image]::FromFile((Resolve-Path 'assets/ai_tech_factory/workshop-background-v2.png'))
$font = [Drawing.Font]::new('Segoe UI',12,[Drawing.FontStyle]::Bold)
$brush = [Drawing.SolidBrush]::new([Drawing.Color]::White)
try {
  for ($i=0; $i -lt $devices.Count; $i++) {
    $d = $devices[$i]
    $x = ($i%4)*432
    $y = [math]::Floor($i/4)*260
    $graphics.DrawImage($backdrop,[Drawing.Rectangle]::new($x,$y,428,234))
    $image = [Drawing.Image]::FromFile((Resolve-Path (Join-Path 'assets/ai_tech_factory' $d[0])))
    try {
      $boundW = [double]$d[4]; $boundH = [double]$d[5]
      $ratio = [math]::Min($boundW/$image.Width,$boundH/$image.Height)
      $w = $image.Width*$ratio/3.0; $h = $image.Height*$ratio/3.0
      $px = $x+([double]$d[2]+($boundW-$w*3.0)/2.0)/3.0
      $py = $y+([double]$d[3]+($boundH-$h*3.0)/2.0)/3.0
      $graphics.DrawImage($image,[Drawing.RectangleF]::new([single]$px,[single]$py,[single]$w,[single]$h))
    }
    finally { $image.Dispose() }
    $graphics.DrawString($d[1],$font,$brush,[single]($x+10),[single]($y+7))
  }
  $bitmap.Save((Join-Path (Get-Location) $output),[Drawing.Imaging.ImageFormat]::Png)
}
finally { $brush.Dispose(); $font.Dispose(); $backdrop.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
