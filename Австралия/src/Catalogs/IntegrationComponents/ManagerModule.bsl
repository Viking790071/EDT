#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure UpdateSettingsFromDataProcessor(RegistrationParameters, SettingObject, ComponentInformation = "") Export
	
	DataProcessor = GetDataProcessor(SettingObject.DataProcessorStorage, RegistrationParameters.DataProcessorDataAddress);
	
	SettingsFromDataProcessor	= DataProcessor.OnDefineSettings();
	
	FillPropertyValues(SettingObject, SettingsFromDataProcessor);
	SettingObject.IsFilled = True;
	ComponentInformation = GetComponentInformation(SettingObject);	
	
EndProcedure

Function GetDataProcessor(DataProcessorStorage, DataProcessorDataAddress = "") Export
	
	If IsBlankString(DataProcessorDataAddress) Then
		DataProcessorDataAddress = PutToTempStorage(DataProcessorStorage.Get());
	EndIf;
	
	Manager = ExternalDataProcessors;
	
	ErrorInformation = Undefined;
	Try
		If Common.HasUnsafeActionProtection() Then
			ObjectName = TrimAll(Manager.Connect(DataProcessorDataAddress,
			,
			False,
			Common.ProtectionWithoutWarningsDetails()));
		Else
			ObjectName = TrimAll(Manager.Connect(DataProcessorDataAddress, , False));
		EndIf;
		
		DataProcessor = Manager.Create(ObjectName);
		
	Except
		ErrorInformation = ErrorInfo();
	EndTry;
	
	Return DataProcessor;	
	
EndFunction

Function GetComponentInformation(Setting) Export
	
	ComponentInformation = "";
	TransferTypes = "";
	If Not Setting.IsFilled Then
		Return ComponentInformation;
	EndIf;
	
	Attributes = Metadata.Catalogs.IntegrationComponents.Attributes;
	
	For Each Attribute In Attributes Do
		
		If Attribute.Name = "DataProcessorStorage"
			Or Attribute.Name = "IsFilled" Then
			Continue;
		EndIf;
		
		If ValueIsFilled(Setting[Attribute.Name]) Then
			
			If Attribute.Type = New TypeDescription("Boolean")
				And StrStartsWith(Attribute.Name, "DataExchange") Then
				
				If Setting[Attribute.Name] Then
					TransferType = StrReplace(Attribute.Synonym, NStr("en = 'Data exchange '; ru = 'Обмен данными ';pl = 'Wymiana danych ';es_ES = 'Intercambio de datos ';es_CO = 'Intercambio de datos ';tr = 'Veri değişimi ';it = 'Scambio dati ';de = 'Datenaustausch '"), "");
					TransferTypes = TransferTypes + "- " + TransferType + ";" + Chars.LF;
				EndIf;
			Else
				ComponentInformation = ComponentInformation + Attribute.Synonym + ": " + Setting[Attribute.Name] + Chars.LF;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	ComponentInformation = ComponentInformation + Chars.LF + NStr("en = 'Data exchange:'; ru = 'Обмен данными:';pl = 'Wymiana danych:';es_ES = 'Intercambio de datos:';es_CO = 'Intercambio de datos:';tr = 'Veri değişimi:';it = 'Scambio dati:';de = 'Datenaustausch:'") + Chars.LF + TransferTypes;
	
	Return ComponentInformation;
	
EndFunction

#EndRegion

#EndIf