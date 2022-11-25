
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	OutboundMessageStatus = NStr("ru = 'Сообщение отправляется...'; en = 'Sending the message...'; pl = 'Wysyłanie wiadomości...';es_ES = 'El mensaje se está enviando...';es_CO = 'El mensaje se está enviando...';tr = 'Mesaj gönderiliyor...';it = 'Inviando il messaggio...';de = 'Die Nachricht wird gesendet...'");
	MessageText = Parameters.Text;
	If TypeOf(Parameters.RecipientsNumbers) = Type("Array") Then
		Separator = "";
		For each PhoneNumber In Parameters.RecipientsNumbers Do
			If TypeOf(PhoneNumber) = Type("Structure") Then
				RecipientsNumbers = RecipientsNumbers + Separator + PhoneNumber.Phone;
			Else
				RecipientsNumbers = RecipientsNumbers + Separator + PhoneNumber;
			EndIf;
			Separator = ",";
		EndDo;
	ElsIf TypeOf(Parameters.RecipientsNumbers) = Type("ValueList") Then
		Separator = "";
		For each PhoneInformation In Parameters.RecipientsNumbers Do 
			RecipientsNumbers = RecipientsNumbers + Separator + PhoneInformation.Value;
			Separator = ",";
		EndDo;
	Else
		RecipientsNumbers = String(Parameters.RecipientsNumbers);
	EndIf;
	
	If IsBlankString(RecipientsNumbers) Then
		Items.RecipientNumberGroup.Visible = True;
	EndIf;
	
	Title = NStr("ru = 'Получатель SMS:'; en = 'Text message to:'; pl = 'Wiadomość SMS do:';es_ES = 'SMS a:';es_CO = 'SMS a:';tr = 'SMS alıcısı:';it = 'Messaggio di testo a:';de = 'Textnachricht an:'") + " " + RecipientsNumbers;
	
	SenderName = SendSMSMessagesCached.SMSMessageSendingSettings().SenderName;
	
	If Parameters.Property("AdditionalParameters") Then
		Parameters.AdditionalParameters.Property("Transliterate", SendInTransliteration);
	EndIf;
	
	SendInTransliteration = False;
	
	If CommonClientServer.IsMobileClient() Then
		
		Items.Move(Items.SMSSendingOpenSetting, Items.CommandBarForm);
		Items.Move(Items.Send, Items.CommandBarForm);
		Items.Move(Items.Close, Items.CommandBarForm);
		Items.Move(Items.Help, Items.CommandBarForm);
		
		CommonClientServer.SetFormItemProperty(Items, "SMSSendingOpenSetting", "OnlyInAllActions", True);
		CommonClientServer.SetFormItemProperty(Items, "Help", "OnlyInAllActions", True);
		CommonClientServer.SetFormItemProperty(Items, "Send", "OnlyInAllActions", False);
		CommonClientServer.SetFormItemProperty(Items, "Send", "Title", NStr("ru ='Отправить'; en = 'Send'; pl = 'Wyślij';es_ES = 'Enviar';es_CO = 'Enviar';tr = 'Gönder';it = 'Inviare';de = 'Senden'"));
		CommonClientServer.SetFormItemProperty(Items, "Close", "OnlyInAllActions", False);
		
		CommonClientServer.SetFormItemProperty(Items, "CommandBarGroup", "Visible", False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	MessageLength = StrLen(MessageText);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AddSenderOnChange(Item)
	Items.SenderName.Enabled = MentionSenderName;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Send(Command)
	
	If StrLen(MessageText) = 0 Then
		ShowMessageBox(, NStr("ru = 'Введите текст.'; en = 'Please enter the text.'; pl = 'Wpisz tekst.';es_ES = 'Por favor, introduzca el texto.';es_CO = 'Por favor, introduzca el texto.';tr = 'Lütfen, metni girin.';it = 'Inserire testo.';de = 'Bitte Text einfügen.'"));
		Return;
	EndIf;
	
	If NOT SMSMessageSendingIsSetUp() Then
		OpenForm("CommonForm.OutboundSMSSettings");
		Return;
	EndIf;
	
	Items.Pages.CurrentPage = Items.StatusPage;
	
	If Items.Find("SMSSendingOpenSetting") <> Undefined Then
		Items.SMSSendingOpenSetting.Visible = False;
	EndIf;
	
	Items.Close.Visible = True;
	Items.Close.DefaultButton = True;
	Items.Send.Visible = False;
	
	// Sending from server context.
	SendSMSMessage();

	// Check a sending status.
	If Not IsBlankString(MessageID) Then
		Items.Pages.CurrentPage = Items.MessageSentPage;
		AttachIdleHandler("CheckDeliveryStatus", 2, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SendSMSMessage()
	
	// Reset a displayed delivery status.
	MessageID = "";
	
	// Prepare recipients numbers.
	NumbersArray = TextLinesToArray(RecipientsNumbers);
	
	// Sending.
	SendingResult = SMS.SendSMSMessage(NumbersArray, MessageText, SenderName, SendInTransliteration);
	
	
	// Display information on errors occurred upon sending.
	If IsBlankString(SendingResult.ErrorDescription) Then
		// Check delivery for the first recipient.
		If SendingResult.SentMessages.Count() > 0 Then
			MessageID = SendingResult.SentMessages[0].MessageID;
		EndIf;
		Items.Pages.CurrentPage = Items.MessageSentPage;
	Else
		Items.Pages.CurrentPage = Items.MessageNotSentPage;
		
		MessageTemplate = NStr("ru = 'Отправка не выполнена:
		|%1
		|Подробности см. в журнале регистрации.'; 
		|en = 'Couldn't send the text message:
		|%1
		|For more details, see the Event log.'");
		
		Items.MessageNotSentText.Title = StringFunctionsClientServer.SubstituteParametersToString(
			MessageTemplate, SendingResult.ErrorDescription);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckDeliveryStatus()
	
	DeliveryResult = DeliveryStatus(MessageID);
	OutboundMessageStatus = DeliveryResult.Details;
	
	DeliveryResults = New Array;
	DeliveryResults.Add("Error");
	DeliveryResults.Add("NotDelivered");
	DeliveryResults.Add("Delivered");
	DeliveryResults.Add("NotSent");
	
	StatusCheckCompleted = DeliveryResults.Find(DeliveryResult.Status) <> Undefined;
	Items.DeliveryStatusCheckGroup.Visible = StatusCheckCompleted;
	
	StateTemplate = NStr("ru = 'Сообщение отправлено. Статус доставки:
		|%1.'; 
		|en = 'Message is sent. Delivery status:
		|%1'; 
		|pl = 'Wiadomość została wysłana. Status dostarczenia:
		|%1';
		|es_ES = 'El mensaje ha sido enviado. Estado de entrega:
		|%1';
		|es_CO = 'El mensaje ha sido enviado. Estado de entrega:
		|%1';
		|tr = 'Mesaj gönderildi. Teslimat durumu:
		|%1';
		|it = 'Il messaggio è stato inviato: Stato di consegna:
		|%1';
		|de = 'Nachricht wurde gesendet. Zustellungsstatus:
		|%1'");
	Items.MessageSentText.Title = StringFunctionsClientServer.SubstituteParametersToString(
		StateTemplate, DeliveryResult.Details);
	
	
	If DeliveryResult.Status = "Error" Then
		Items.AnimationDecoration.Picture = PictureLib.Error32;
	Else
		If DeliveryResults.Find(DeliveryResult.Status) <> Undefined Then
			Items.AnimationDecoration.Picture = PictureLib.Done32;
			Items.DeliveryStatusCheckGroup.Visible = False;
		Else
			AttachIdleHandler("CheckDeliveryStatus", 2, True);
			Items.DeliveryStatusCheckGroup.Visible = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function DeliveryStatus(MessageID)
	
	DeliveryStatuses = New Map;
	DeliveryStatuses.Insert("Error", NStr("ru = 'Ошибка подключения поставщика SMS'; en = 'SMS provider connection error'; pl = 'Błąd połączenia z operatorem wysyłki SMS';es_ES = 'Error de conexión del proveedor de SMS';es_CO = 'Error de conexión del proveedor de SMS';tr = 'SMS sağlayıcı bağlantı hatası';it = 'Errore di connessione del provider SMS';de = 'Verbindungsfehler des SMS-Anbieters'"));
	DeliveryStatuses.Insert("Pending", NStr("ru = 'Поставщик поставил сообщение в очередь для доставки'; en = 'Provider queued message for delivery'; pl = 'Operator dodał wiadomość SMS do kolejki wysyłki';es_ES = 'Mensaje en cola del proveedor para su entrega';es_CO = 'Mensaje en cola del proveedor para su entrega';tr = 'Sağlayıcı, mesajı teslim etmek üzere sıraya aldı';it = 'Il provider ha inserito in coda di consegna il messaggio';de = 'Anbieter hat die Nachricht für Zustellung angestellt'"));
	DeliveryStatuses.Insert("Sending", NStr("ru = 'Поставщик доставляет сообщение'; en = 'Provider is delivering message'; pl = 'Operator wysyła wiadomość SMS';es_ES = 'El proveedor está entregando el mensaje';es_CO = 'El proveedor está entregando el mensaje';tr = 'Sağlayıcı, mesajı teslim ediyor';it = 'Il provider sta inviando il messaggio';de = 'Anbieter stellt die Nachricht zu'"));
	DeliveryStatuses.Insert("Sent", NStr("ru = 'Поставщик отправил сообщение'; en = 'Provider sent the message'; pl = 'Operator wysłał wiadomość SMS';es_ES = 'El proveedor envió el mensaje';es_CO = 'El proveedor envió el mensaje';tr = 'Sağlayıcı, mesajı gönderdi';it = 'Il provider ha inviato il messaggio';de = 'Anbieter hat die Nachricht gesendet'"));
	DeliveryStatuses.Insert("NotSent", NStr("ru = 'Поставщик не отправил сообщение'; en = 'Provider did not send message'; pl = 'Operator nie wysłał wiadomości SMS';es_ES = 'El proveedor no envió el mensaje';es_CO = 'El proveedor no envió el mensaje';tr = 'Sağlayıcı, mesajı göndermedi';it = 'Il provider non ha inviato il messaggio';de = 'Anbieter hat keine Nachricht gesendet'"));
	DeliveryStatuses.Insert("Delivered", NStr("ru = 'Сообщение доставлено'; en = 'Message is delivered'; pl = 'Wiadomość została dostarczona';es_ES = 'El mensaje se ha entregado';es_CO = 'El mensaje se ha entregado';tr = 'Mesaj teslim edildi';it = 'Il messaggio è stato inviato';de = 'Die Nachricht wurde zugestellt'"));
	DeliveryStatuses.Insert("NotDelivered", NStr("ru = 'Сообщение не доставлено'; en = 'Message is not delivered'; pl = 'Wiadomość nie została dostarczona';es_ES = 'Mensaje no entregado';es_CO = 'Mensaje no entregado';tr = 'Mesaj teslim edilmedi';it = 'Il messaggio non è stato inviato';de = 'Die Nachricht wurde nicht zugestellt'"));
	
	DeliveryResult = New Structure("Status, Details");
	DeliveryResult.Status = SMS.DeliveryStatus(MessageID);
	DeliveryResult.Details = DeliveryStatuses[DeliveryResult.Status];
	If DeliveryResult.Details = Undefined Then
		DeliveryResult.Details = "<" + DeliveryResult.Status + ">";
	EndIf;
	
	Return DeliveryResult;
	
EndFunction

&AtServer
Function TextLinesToArray(Text)
	
	Result = New Array;
	
	TextDocument = New TextDocument;
	TextDocument.SetText(Text);
	
	For RowNumber = 1 To TextDocument.LineCount() Do
		Row = TextDocument.GetLine(RowNumber);
		If Not IsBlankString(Row) Then
			Result.Add(Row);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure TextChangeEditText(Item, Text, StandardProcessing)
	MessageLength = StrLen(Text);
	StandardProcessing = False;
EndProcedure

&AtServerNoContext
Function SMSMessageSendingIsSetUp()
 	Return SMS.SMSMessageSendingSetupCompleted();
EndFunction

#EndRegion
