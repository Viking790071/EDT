
#Region Private

////////////////////////////////////////////////////////////////////////////////
// Web service operation handlers

// Matches the DeliverMessages web service operation.
Function DeliverMessages(SenderCode, StreamStorage)
	
	SetPrivilegedMode(True);
	
	// Getting the sender link.
	Sender = ExchangePlans.MessageExchange.FindByCode(SenderCode);
	
	If Sender.IsEmpty() Then
		
		Raise NStr("ru = 'Invalid endpoint connection settings.'; en = 'Invalid endpoint connection settings.'; pl = 'Invalid endpoint connection settings.';es_ES = 'Invalid endpoint connection settings.';es_CO = 'Invalid endpoint connection settings.';tr = 'Invalid endpoint connection settings.';it = 'Invalid endpoint connection settings.';de = 'Invalid endpoint connection settings.'");
		
	EndIf;
	
	ImportedMessages = Undefined;
	DataReadPartially = False;
	
	// Importing messages to the infobase.
	MessageExchangeInternal.SerializeDataFromStream(
		Sender,
		StreamStorage.Get(),
		ImportedMessages,
		DataReadPartially);
	
	// Processing message queue.
	If Common.FileInfobase() Then
		
		MessageExchangeInternal.ProcessSystemMessageQueue(ImportedMessages);
		
	Else
		
		ProcedureParameters = New Structure;
		ProcedureParameters.Insert("ImportedMessages", ImportedMessages);
		
		ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
		ExecutionParameters.RunInBackground = True;
		
		BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
			"MessageExchangeInternal.ProcessSystemMessageQueueInBackground",
			ProcedureParameters,
			ExecutionParameters);
		
	EndIf;
	
	If DataReadPartially Then
		
		Raise NStr("ru = 'An error occurred when delivering instant messages. Some messages
                                |were not delivered due to the set locks of data areas.
                                |
                                |These messages will be processed within the queue for processing system messages.'; 
                                |en = 'An error occurred when delivering instant messages. Some messages
                                |were not delivered due to the set locks of data areas.
                                |
                                |These messages will be processed within the queue for processing system messages.'; 
                                |pl = 'An error occurred when delivering instant messages. Some messages
                                |were not delivered due to the set locks of data areas.
                                |
                                |These messages will be processed within the queue for processing system messages.';
                                |es_ES = 'An error occurred when delivering instant messages. Some messages
                                |were not delivered due to the set locks of data areas.
                                |
                                |These messages will be processed within the queue for processing system messages.';
                                |es_CO = 'An error occurred when delivering instant messages. Some messages
                                |were not delivered due to the set locks of data areas.
                                |
                                |These messages will be processed within the queue for processing system messages.';
                                |tr = 'An error occurred when delivering instant messages. Some messages
                                |were not delivered due to the set locks of data areas.
                                |
                                |These messages will be processed within the queue for processing system messages.';
                                |it = 'An error occurred when delivering instant messages. Some messages
                                |were not delivered due to the set locks of data areas.
                                |
                                |These messages will be processed within the queue for processing system messages.';
                                |de = 'An error occurred when delivering instant messages. Some messages
                                |were not delivered due to the set locks of data areas.
                                |
                                |These messages will be processed within the queue for processing system messages.'");
		
	EndIf;
	
EndFunction

// Matches the DeliverMessages web service operation.
Function GetInfobaseParameters(ThisEndpointDescription)
	
	SetPrivilegedMode(True);
	
	If IsBlankString(MessageExchangeInternal.ThisNodeCode()) Then
		
		ThisNodeObject = MessageExchangeInternal.ThisNode().GetObject();
		ThisNodeObject.Code = String(New UUID());
		ThisNodeObject.Description = ?(IsBlankString(ThisEndpointDescription),
									MessageExchangeInternal.ThisNodeDefaultDescription(),
									ThisEndpointDescription);
		ThisNodeObject.Write();
		
	ElsIf IsBlankString(MessageExchangeInternal.ThisNodeDescription()) Then
		
		ThisNodeObject = MessageExchangeInternal.ThisNode().GetObject();
		ThisNodeObject.Description = ?(IsBlankString(ThisEndpointDescription),
									MessageExchangeInternal.ThisNodeDefaultDescription(),
									ThisEndpointDescription);
		ThisNodeObject.Write();
		
	EndIf;
	
	ThisPointParameters = Common.ObjectAttributesValues(MessageExchangeInternal.ThisNode(), "Code, Description");
	
	Result = New Structure;
	Result.Insert("Code",          ThisPointParameters.Code);
	Result.Insert("Description", ThisPointParameters.Description);
	
	Return ValueToStringInternal(Result);
EndFunction

// Matches the ConnectEndpoint web service operation.
Function ConnectEndpoint(Code, Description, RecipientConnectionSettingsString)
	
	Cancel = False;
	
	MessageExchangeInternal.ConnectEndpointAtRecipient(Cancel, Code, Description, ValueFromStringInternal(RecipientConnectionSettingsString));
	
	Return Not Cancel;
EndFunction

// Matches the UpdateConnectionSettings web service operation.
Function UpdateConnectionSettings(Code, ConnectionSettingsString)
	
	ConnectionSettings = ValueFromStringInternal(ConnectionSettingsString);
	
	SetPrivilegedMode(True);
	
	Endpoint = ExchangePlans.MessageExchange.FindByCode(Code);
	If Endpoint.IsEmpty() Then
		Raise NStr("ru = 'Invalid endpoint connection settings.'; en = 'Invalid endpoint connection settings.'; pl = 'Invalid endpoint connection settings.';es_ES = 'Invalid endpoint connection settings.';es_CO = 'Invalid endpoint connection settings.';tr = 'Invalid endpoint connection settings.';it = 'Invalid endpoint connection settings.';de = 'Invalid endpoint connection settings.'");
	EndIf;
	
	BeginTransaction();
	Try
		
		// Updating connection settings.
		RecordStructure = New Structure;
		RecordStructure.Insert("Endpoint", Endpoint);
		
		RecordStructure.Insert("WebServiceAddress", ConnectionSettings.WSWebServiceURL);
		RecordStructure.Insert("UserName", ConnectionSettings.WSUsername);
		RecordStructure.Insert("Password",          ConnectionSettings.WSPassword);
		RecordStructure.Insert("RememberPassword", True);
		
		// Adding information register record
		InformationRegisters.MessageExchangeTransportSettings.UpdateRecord(RecordStructure);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndFunction

// Matches the SetLeadingEndPoint web service operation.
Function SetLeadingEndpoint(ThisEndpointCode, LeadingEndpointCode)
	
	MessageExchangeInternal.SetLeadingEndpointAtRecipient(ThisEndpointCode, LeadingEndpointCode);
	
EndFunction

// Matches the TestConnectionAtRecipient web service operation.
Function TestConnectionAtRecipient(ConnectionSettingsString, SenderCode)
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	WSProxy = MessageExchangeInternal.GetWSProxy(ValueFromStringInternal(ConnectionSettingsString), ErrorMessageString);
	
	If WSProxy = Undefined Then
		Raise ErrorMessageString;
	EndIf;
	
	WSProxy.TestConnectionSender(SenderCode);
	
EndFunction

// Matches the TestConnectionAtSender web service operation .
Function TestConnectionAtSender(SenderCode)
	
	SetPrivilegedMode(True);
	
	If MessageExchangeInternal.ThisNodeCode() <> SenderCode Then
		
		Raise NStr("ru = 'Sender infobase connection settings indicate another recipient.'; en = 'Sender infobase connection settings indicate another recipient.'; pl = 'Sender infobase connection settings indicate another recipient.';es_ES = 'Sender infobase connection settings indicate another recipient.';es_CO = 'Sender infobase connection settings indicate another recipient.';tr = 'Sender infobase connection settings indicate another recipient.';it = 'Sender infobase connection settings indicate another recipient.';de = 'Sender infobase connection settings indicate another recipient.'");
		
	EndIf;
	
EndFunction

#EndRegion
