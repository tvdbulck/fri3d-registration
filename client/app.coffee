Stripe.setPublishableKey Meteor.settings.public.stripe_pk

Router.configure
	layoutTemplate: "layout"

@RegistrationSub = Meteor.subscribe "registrations"

Meteor.subscribe "userData"

Meteor.subscribe "tickets"
Meteor.subscribe "merchandising"
Meteor.subscribe "tokens"

Router.map ()->
	this.route "welcome",
			path: "/"
	this.route "practical", {}
	this.route "pricing", {}
	this.route "preregistration", {}
	this.route "mailing"
	this.route "users"
	this.route "ticketing"
	this.route "addticket"
	this.route "addmerchandising"
	this.route "addtokens"

Template.navigation.style = (path)->
	style = if Router.current() and  Router.current().route.name is path then "active" else "inactive"
	return style

Template.preregister.events
	"change #amount": (event, template) ->
		amount = event.target.value
	"click #addPreregistration": (event,template) ->
		event.preventDefault()
		Errors.clearAll()
		registration =
			remarks: template.find("#remarks").value
			tickets: []
		amounts = template.findAll "input.amount"
		_.each amounts, (amount)->
			ticket =
				amount: parseInt amount.value
				type: amount.getAttribute "name"
			if ticket.amount > 0
				registration.tickets.push ticket
		if !Meteor.user()
			# if the user is not logged in yet, we're assuming a registration is in order
			options =
				email: template.find("#email").value.toLowerCase()
				password: template.find("#password").value
			Meteor.call "user_exists", options.email, (error,result)->
				if error
					Errors.throw error, "registration"
				if result
					Meteor.loginWithPassword options.email, options.password, (error)->
						if error
							Errors.throw error, "registration"
						else
							if registration.tickets.length > 0
								register registration
				else
					Accounts.createUser options, (error)->
						if error
							Errors.throw error, "registration"
						else
							register registration
		# Already logged in!
		else
			register registration
		return

@register = (registration)->
		if registration.tickets.length is 0
			Errors.throw "Please specify at least one ticket amount", "registration"
			return
		Meteor.call "register",registration, (error)->
			if error
				Errors.throw error, "registration"
			else
				Errors.throw "You have successfully (pre)registered tickets. You can view them below.", "registration_success"
				$('html,body').animate({scrollTop: $('a[name=#registrations]').offset().top},'slow')

Template.jumbotron.statistics = ()->
		statistics =
			total: 256
			preregistrations: 0
		_.each Registrations.find({}).fetch(), (registration)->
			statistics.preregistrations += registration.amount
		statistics.remaining = statistics.total - statistics.preregistrations
		if statistics.remaining < 1
			statistics.soldout = true
			statistics.style = "soldout"
		else
			statistics.style = "open"
		return statistics

# The countdown timer:
countDown = ()->
	launch = moment.utc(Meteor.settings.public.launch)
	now = moment.utc()
	Session.set "countdown", launch.fromNow()
	if now.isAfter(launch)
		Session.set "launched", true
		id = Session.get "countdown_id"
		if id
			Meteor.clearInterval id

Meteor.startup ()->
	Session.set "launched", false
	countdown_id = Meteor.setInterval countDown, 1000

Template.preregister.open = ()-> Session.get "launched"

Template.preregister.countdown = ()-> Session.get "countdown"

# (Pre-)registration listings:

Template.registrations.hasRegistrations = ()->
		Registrations.find({owner:Meteor.userId()}).count() > 0


Template.registrations.list = ()-> Registrations.find {owner:Meteor.userId()}

Template.registrations.total = ()->
		total =
			amount: 0
			cost: 0
		_.each Registrations.find({owner:Meteor.userId()}).fetch(), (registration)->
			total.amount += registration.amount
			total.cost += registration.subtotal
		return total

Template.registration.events
	"click .remove": (event,template)->
		event.preventDefault()
		confirmed = confirm "Are you sure you want to delete this preregistration?"
		if confirmed
			Registrations.remove {_id:this._id}
		return

Template.mailing.events
	"click #send": (event,template)->
		event.preventDefault()
		if confirm "Are you sure you want to send this to all registered users?"
				subject = template.find("#subject").value
				text = template.find("#text").value
				Meteor.call "mailing", subject, text, (error)->
					if error
						alert error
					else
						alert "Mailing was sent!"

Template.users.list = ()-> Meteor.users.find {}

Template.users.helpers
	"registrations": (_id)-> Registrations.find {owner: _id}

Template.login.message = ()-> Session.get "login_message"

Template.login.events
	"click #logout": (event,template)->
		Meteor.logout()
		return
	"click #login": (event,template)->
		event.preventDefault()
		Session.set "login_message", null
		email = template.find("#email").value
		password = template.find("#password").value
		Meteor.loginWithPassword email,password, (error)->
			if error
				Session.set "login_message", {text:error.reason,style:"danger"}
		return
	"click #alzheimer": (event,template)->
		event.preventDefault()
		email = template.find("#email").value
		if !email or email is ""
			Session.set "login_message", {text:"Please provide an email address",style:"danger"}
			return
		email = email.toLowerCase()
		Accounts.forgotPassword {email:email}, (error)->
			if error
				Session.set "login_message", {text:error.reason,style:"danger"}
			else
				Session.set "login_message", {text:"Check your mail!",style:"success"}
		return

Template.addticket.events
	"click #submitTicket": (event,template)->
			Session.set "ticket_message", null
			ticket =
				first_name: template.find("#first_name").value
				last_name: template.find("#last_name").value
				birthday:  template.find("#birthday").value
				type: template.find("#type").value
				volunteer:
					infobooth: template.find("#volunteer_infobooth").checked
					security: template.find("#volunteer_security").checked
					drinks: template.find("#volunteer_drinks").checked
					standby: template.find("#volunteer_standby").checked
					night: template.find("#volunteer_night").checked
				veggie: template.find("#veggie").checked
				arrival:
					date:  template.find("#arrival_date").value
					time:  template.find("#arrival_time").value
				departure:
					date:  template.find("#departure_date").value
					time:  template.find("#departure_time").value
			Meteor.call "addticket", ticket, (error)->
				if error
					Session.set "ticket_message", {text:error.reason,style:"danger"}
				else
					Session.set "ticket_message", {text: "Your ticket was added. Don't forget to checkout", style: "success"}
			return

Template.addticket.message = ()-> Session.get "ticket_message"

Template.tickets.list = ()-> Tickets.find {}

Template.tickets.events
	"click #removeTicket": (event,template)->
			confirmed = confirm "Are you sure you want to delete this ticket?"
			if confirmed
				Tickets.remove {_id:this._id}
			return

Template.merchandising.list = ()-> Merchandising.find {}

Template.merchandising.events
	"click #removeMerchandising": (event,template)->
		confirmed = confirm "Are you sure you want to cancel this T-shirt order?"
		if confirmed
			Merchandising.remove {_id:this._id}
		return

Template.addmerchandising.events
	"click #addMerchandising": (event,template)->
		event.preventDefault()
		size = template.find("#size").value
		Meteor.call "addmerchandising", size, (error)->
			if error
				Session.set "merchandising_message", {text:error.message,style:"danger"}
		return

Template.checkout.total = ()->
	total = 0
	Tickets.find({paid:false}).forEach (ticket)-> total += ticket.amount
	Merchandising.find({paid:false}).forEach (merch)-> total += merch.amount
	return total

Template.checkout.events
	"click #stripeCheckout": (event,template)->
		event.preventDefault()
		Session.set "stripe_message", null
		# Router.go '/loading'
		# Session.set ""
		card_number = template.find('#card_number').value
		cvc_check = parseInt(template.find('#cvc_check').value)
		type = template.find('#card_type').value
		name = template.find('#name').value
		exp_month = template.find('#month').value
		exp_year = template.find('#year').value
		card = {'number':card_number, 'exp_month':exp_month, 'exp_year':exp_year, 'cvc':cvc_check, 'name':name, 'type':type}
		Stripe.card.createToken card, (status, response) ->
			if response.error
				Session.set "stripe_message", {text:response.error.message,style:"danger"}
			else
				card_token = response.id
				Meteor.call 'creditcard_payment', card_token, (error, result) ->
					if error
						Session.set "stripe_message", {text:error.message,style:"danger"}
					else
						Session.set "stripe_message", {text:"Your payment was succesfull!",style:"success"}

Template.checkout.stripe_message = ()-> Session.get "stripe_message"

UI.registerHelper "admin", ()->
	return Meteor.user() and Meteor.user().role is "admin"

UI.registerHelper "ticketCost", (type)->
	type =_.findWhere tickettypes, {type: type}
	return type.cost 
	
