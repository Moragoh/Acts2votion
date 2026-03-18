<overview>
Acts2votion is a client app/widget for "Devotionals," where people meditate on a given Bible verse for today with discussion questions. This app queries what the bible verse / content of the day is from https://moragoh.github.io/Act2votion-server/devotional.json

It then displays what the "verses" is for the day on the widget.

When someone clicks on the widget, it opens the app which shows the "verses" as well as the "content"
</overview>

<style>
The app should be minimalistic with no frills. It displays information in a clean professional font (think Times New Roman). It should have dark and light mode that changes based on the system settings.
</style>

<content-styling>
The content of the json file at the link is made up of subheaders and bullet points like this

 "content": "John 8:31-36\n• Most people would say, as the people did in v. 33, “We…have never been enslaved to anyone.” In what ways are people today enslaved?\n• How has Jesus set me free from being “a slave to sin”?\nJohn 8:37, 43-44, 47\n• Jesus is addressing those who have already decided to kill him. What is the reason for their rejection of Jesus?  How does Jesus’ warning—that the issue is not a lack of clarity but their hostile relationship with truth—apply today? Are there times I have found spiritual issues confusing because my desires have clouded the truth?\nJohn 8:44-46\n• Consider the sobering statement here about lying. How am I challenged about my speech?"

 It should display the content properly. It should have the subheading, followed by the bullet points that belong to it in indented bullet points.
So for the above example, the app should format it as such:
John 8:31-36
• Most people would say, as the people did in v. 33, “We…have never been enslaved to anyone.” In what ways are people today enslaved?
• How has Jesus set me free from being “a slave to sin”? 

John 8:37, 43-44, 47
• Jesus is addressing those who have already decided to kill him. What is the reason for their rejection of Jesus?  How does Jesus’ warning—that the issue is not a lack of clarity but their hostile relationship with truth—apply today? Are there times I have found spiritual issues confusing because my desires have clouded the truth?

John 8:44-46
• Consider the sobering statement here about lying. How am I challenged about my speech?"
</content-styling>

<updates>
There are two considerations to updates: How often it should pull from the website, and how often the widget itself should refresh. 

Widgets cannot update too often. Think about how often this widget should refresh. 

It realistically only needs to fetch the json at most once a day (4 AM EST). I think it would be better if it could download the json from the website once a day and query it locally to update the app and the widget. What do you think of this approach?
</updates>


