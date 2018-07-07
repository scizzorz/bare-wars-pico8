from PIL import Image
import io
rewrite = io.StringIO()

color_map = {
  (0, 135, 81): 64,
  (255, 0, 77): 66,
  (171, 82, 54): 68,
  (41, 173, 255): 70,
  (131, 118, 156): 64,
}

new_map = []

with Image.open('map.png') as fp:
  pix = fp.load()
  w, h = fp.size

  for y in range(h):
    new_map.append([])
    for x in range(w):
      new_map[y % 32].append(color_map[pix[x, y]])

with open('barewars.p8') as fp:
  for line in fp:
    rewrite.write(line)
    if line.strip() == '__map__':
      break

  tiles = [line.strip() for _, line in zip(range(32), fp)]
  tiles = [[int(line[x*2:(x+1)*2], 16) for x in range(64)] for line in tiles]

  for y in new_map:
    for x in y:
      rewrite.write(f'{x:02x}')
    rewrite.write('\n')

  for line in fp:
    rewrite.write(line)

with open('barewars.p8', 'w') as fp:
  fp.write(rewrite.getvalue())
