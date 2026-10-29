const fs = require('fs');
const path = require('path');

function walk(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    const fullPath = path.join(dir, file);
    const stat = fs.statSync(fullPath);
    if (stat && stat.isDirectory()) {
      results = results.concat(walk(fullPath));
    } else if (file.endsWith('.dart') && !file.endsWith('.g.dart')) {
      results.push(fullPath);
    }
  });
  return results;
}

const files = walk(path.join(__dirname, '../dogo-flutter/lib'));

console.log(`Found ${files.length} dart files.`);

const screens = [];

files.forEach(f => {
  const content = fs.readFileSync(f, 'utf8');
  if (content.includes('class ') && (content.includes('extends StatelessWidget') || content.includes('extends StatefulWidget')) && (f.includes('screen') || content.includes('Scaffold('))) {
    const hasScaffold = content.includes('Scaffold(');
    const hasAppBar = content.includes('appBar:');
    const hasCanPop = content.includes('canPop');
    const hasArrowBack = content.includes('arrow_back') || content.includes('arrow_back_rounded') || content.includes('close_rounded');
    screens.push({
      file: path.relative(path.join(__dirname, '../dogo-flutter/lib'), f),
      hasScaffold,
      hasAppBar,
      hasCanPop,
      hasArrowBack
    });
  }
});

console.log(JSON.stringify(screens, null, 2));

