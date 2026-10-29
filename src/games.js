export const GAMES = {
  would:{title:'Would You Rather',kicker:'TWO CHOICES. ONE ROOM.',prompts:[
    {q:'Would you rather read minds or see 10 minutes into the future?',a:'Read minds',b:'See the future'},
    {q:'Would you rather have a personal chef or a personal driver for life?',a:'Personal chef',b:'Personal driver'},
    {q:'Would you rather relive your best day or erase your most embarrassing one?',a:'Relive my best day',b:'Erase the embarrassment'},
    {q:'Would you rather always be 15 minutes early or 10 minutes late?',a:'Always early',b:'Usually late'},
    {q:'Would you rather have unlimited energy or unlimited free time?',a:'Unlimited energy',b:'Unlimited free time'}]},
  truth:{title:'Truth or Dare',kicker:'BE BRAVE. BE KIND.',prompts:[
    {q:'Truth: What is a small thing that instantly improves your day?',a:'Truth',b:'Dare'},
    {q:'Dare: Give someone in the room a sincere compliment.',a:'I did it',b:'Skip'},
    {q:'Truth: What is something you are proud of but rarely mention?',a:'Truth',b:'Dare'},
    {q:'Dare: Share a harmless, funny misunderstanding you once had.',a:'I did it',b:'Skip'}]},
  likely:{title:'Most Likely To',kicker:'POINT AT YOUR PEOPLE.',prompts:[
    {q:'Who is most likely to turn a quick outing into an adventure?',a:'Vote for a player',b:'Skip vote'},
    {q:'Who is most likely to remember everyone’s birthday?',a:'Vote for a player',b:'Skip vote'},
    {q:'Who is most likely to laugh at the worst possible moment?',a:'Vote for a player',b:'Skip vote'}]},
  never:{title:'Never Have I Ever',kicker:'STORIES WILL FOLLOW.',prompts:[
    {q:'Never have I ever pretended to understand something and hoped nobody noticed.',a:'I have',b:'Never'},
    {q:'Never have I ever laughed so hard I cried.',a:'I have',b:'Never'},
    {q:'Never have I ever sent a message to the wrong person.',a:'I have',b:'Never'}]},
  couples:{title:'Couples',kicker:'GET TO KNOW EACH OTHER.',prompts:[
    {q:'What ordinary moment with your partner do you treasure?',a:'Share',b:'Pass'},
    {q:'What makes you feel most appreciated in a relationship?',a:'Share',b:'Pass'},
    {q:'What new experience would you love to share together?',a:'Share',b:'Pass'}]},
  family:{title:'Family Friendly',kicker:'ALL AGES, GOOD ENERGY.',prompts:[
    {q:'If our family could take a trip anywhere, where should we go?',a:'Share',b:'Pass'},
    {q:'What meal always feels like home?',a:'Share',b:'Pass'},
    {q:'What is one funny family memory you still talk about?',a:'Share',b:'Pass'}]}
};
export const gameOptions=Object.entries(GAMES).map(([id,g])=>({id,name:g.title,desc:g.kicker,tag:g.kicker}));