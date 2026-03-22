<objective>
Create a companion widget for the app.
</objective>

<detail>
The widget should simply display what today's Bible verse is.
It should say the book name at the top, then new line and the verses for that day.
So for example, if the verse is John 3:16-20, the widget should say

John
3:16-20

Keep the design minimalist. Black text on white for light mode, and white text on black for light mode. 
The verses text should be slightly less "brighter" than the book text.

Use Georgia font.

Also, the widget only needs to small size. I know the doc says it should have all sizes. Ignore that.
</detail>

<update-policy>
The widget should automatically refresh by itself at 4 AM by reading today's verses from cache. This needs to happen at 4 AM so that when people do their DTs 1st thing in the morning, it is updated.

Other than that, it should trigger a refresh whenever the app is opened. But this can make iOS throttle the widget refresh, so don't make it do it too much.
</update-policy>