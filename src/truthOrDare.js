const truthPrompts = [
["Funny","What is the most ridiculous thing you have done to impress someone?"],
["Funny","What is your most embarrassing text-message moment?"],
["Confession","What is something you have kept secret from most friends?"],
["Confession","When did you last pretend to like something to impress someone?"],
["Relationship","What is your biggest green flag in a partner?"],
["Relationship","What is the most thoughtful romantic gesture you have received?"],
["Flirty","What small gesture makes someone instantly more attractive?"],
["Flirty","What is the boldest move you have made on someone you liked?"],
["Deep","What is something you are still learning to accept about yourself?"],
["Deep","What does feeling loved look like to you?"],
["18+ intimate", "What is your biggest turn-on that has nothing to do with appearance?", true],
["18+ intimate", "What kind of kiss do you find hardest to forget?", true],
["18+ intimate", "What is one intimate boundary you consider important?", true],
["18+ intimate", "What helps you feel safe and desired in a consensual relationship?", true]
];
const darePrompts = [
["Funny","Give a dramatic 20-second weather report about this room."],
["Funny","Do your best impression of someone famous."],
["Funny","Make up a dance move and teach it to everyone."],
["Bold","Give someone a sincere, specific compliment."],
["Bold","Share a harmless mistake that taught you something."],
["Romantic","Describe your perfect date in 30 seconds."],
["Romantic","Deliver your best movie-style romantic line."],
["Naughty","Show your best flirtatious eyebrow raise."],
["Naughty","Deliver your smoothest pickup line with a straight face."],
["Naughty","Act out how you behave when you have a crush."],
["18+ intimate","Give a willing partner a brief hand massage, only with clear consent.",true],
["18+ intimate","Describe your ideal romantic atmosphere without naming anyone.",true],
["18+ intimate","Share one non-explicit thing that makes intimacy feel special.",true]
];
function shuffle(items, seed) {
  const a=[...items]; let n=0;
  for(let i=0;i<seed.length;i++) n=(n*31+seed.charCodeAt(i))>>>0;
  for(let i=a.length-1;i>0;i--){n=(n*1664525+1013904223)>>>0;const j=n%(i+1);[a[i],a[j]]=[a[j],a[i]];}
  return a;
}
export function getTruthDareCount(choice='truth',adult=false) { const source=choice==='dare'?darePrompts:truthPrompts; return source.filter(x=>adult||!x[2]).length; }
export function getTruthDarePrompt(choice,index,room,adult=false) {
  const source=(choice==="truth"?truthPrompts:darePrompts).filter(x=>adult||!x[2]);
  const ordered=shuffle(source,(room||"GOODCO")+":"+choice);
  const p=ordered[index%ordered.length];
  return {category:p[0],text:p[1]};
}
