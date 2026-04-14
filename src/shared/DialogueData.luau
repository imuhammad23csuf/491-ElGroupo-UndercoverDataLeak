local DialogueData = {
	-- ======================
	-- ORIGINAL INTRO
	-- ======================
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

	-- ======================
	-- SCENARIO 1: CONFIDENTIALITY VS TRANSPARENCY
	-- ======================
	EthicalScenario1 = {
		start = "node1",

		nodes = {
			node1 = {
				text = "You discover sensitive student data left exposed. What do you do?",
				choices = {
					{
						text = "Report it immediately.",
						next = "node2",
						integrity = 10,
					},
					{
						text = "Ignore it to avoid trouble.",
						next = "node3",
						integrity = -10,
					},
				},
			},

			node2 = {
				text = "Your report helps secure the system.",
				choices = {
					{
						text = "Continue",
						next = "endGood",
						integrity = 5,
					},
				},
			},

			node3 = {
				text = "The data is later leaked, causing damage.",
				choices = {
					{
						text = "Continue",
						next = "endBad",
						integrity = -5,
					},
				},
			},

			endGood = {
				text = "You acted ethically and prevented harm.",
				choices = {},
				isEnd = true,
			},

			endBad = {
				text = "Your inaction contributed to a breach.",
				choices = {},
				isEnd = true,
			},
		},
	},

	-- ======================
	-- SCENARIO 2: REPORTING VS LOYALTY
	-- ======================
	EthicalScenario2 = {
		start = "node1",

		nodes = {
			node1 = {
				text = "Your friend is bypassing security rules. What do you do?",
				choices = {
					{
						text = "Report your friend.",
						next = "node2",
						integrity = 10,
					},
					{
						text = "Stay loyal and say nothing.",
						next = "node3",
						integrity = -10,
					},
				},
			},

			node2 = {
				text = "Security improves, but your friend is upset.",
				choices = {
					{
						text = "Continue",
						next = "endGood",
						integrity = 5,
					},
				},
			},

			node3 = {
				text = "The vulnerability is exploited later.",
				choices = {
					{
						text = "Continue",
						next = "endBad",
						integrity = -5,
					},
				},
			},

			endGood = {
				text = "You prioritized security over loyalty.",
				isEnd = true,
				choices = {},
			},

			endBad = {
				text = "Your silence allowed the problem to grow.",
				isEnd = true,
				choices = {},
			},
		},
	},

	-- ======================
	-- SCENARIO 3: COWORKER BEHAVIOR
	-- ======================
	EthicalScenario3 = {
		start = "node1",

		nodes = {
			node1 = {
				text = "You notice a coworker sharing passwords insecurely. What do you do?",
				choices = {
					{
						text = "Advise them to follow security practices.",
						next = "node2",
						integrity = 10,
					},
					{
						text = "Ignore it, it's not your problem.",
						next = "node3",
						integrity = -10,
					},
				},
			},

			node2 = {
				text = "They thank you and improve their behavior.",
				choices = {
					{
						text = "Continue",
						next = "endGood",
						integrity = 5,
					},
				},
			},

			node3 = {
				text = "The insecure behavior leads to a system breach.",
				choices = {
					{
						text = "Continue",
						next = "endBad",
						integrity = -5,
					},
				},
			},

			endGood = {
				text = "You helped prevent a security issue.",
				isEnd = true,
				choices = {},
			},

			endBad = {
				text = "Ignoring the issue caused serious consequences.",
				isEnd = true,
				choices = {},
			},
		},
	},
}

return DialogueData