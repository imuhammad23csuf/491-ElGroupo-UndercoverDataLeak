local DialogueData = {
	Intro = {
		start = "node1",

		nodes = {
			node1 = {
				text = "You find a suspicious USB drive on a teacher's desk. What do you do?",
				choices = {
					{
						text = "Turn it in immediately.",
						next = "node2",
						integrity = 10,
					},
					{
						text = "Plug it into a school computer.",
						next = "node3",
						integrity = -15,
					},
				},
			},

			node2 = {
				text = "You reported the device. The administrator thanks you for doing the right thing.",
				choices = {
					{
						text = "Continue",
						next = "node4",
						integrity = 0,
					},
				},
			},

			node3 = {
				text = "The computer begins acting strangely. That was a risky choice.",
				choices = {
					{
						text = "Continue",
						next = "node4",
						integrity = 0,
					},
				},
			},

			node4 = {
				text = "Later, a friend asks if you want to hide what happened.",
				choices = {
					{
						text = "Tell the truth.",
						next = "goodEnding",
						requiredGate = "WhistleblowerPath",
						integrity = 10,
					},
					{
						text = "Hide the evidence.",
						next = "badEnding",
						requiredGate = "CorporateSpyPath",
						integrity = -20,
					},
				},
			},

			goodEnding = {
				text = "Your honesty helps protect the school network.",
				choices = {},
				isEnd = true,
			},

			badEnding = {
				text = "The cover-up makes the situation worse.",
				choices = {},
				isEnd = true,
			},
		},
	},
}

return DialogueData