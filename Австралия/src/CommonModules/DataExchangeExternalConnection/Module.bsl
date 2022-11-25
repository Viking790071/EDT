#Region Public

// Returns data from a list of objects of the specified metadata object as a system presentation.
// 
// Parameters:
//  FullTableName - String - a name of the table that corresponds to the metadata object.
// 
// Returns:
//  String - system presentation of a value table containing data of the specified metadata object.
//
Function GetTableObjects(FullTableName) Export
	
	Return ValueToStringInternal(Common.ValueFromXMLString(DataExchangeServer.GetTableObjects(FullTableName)));
	
EndFunction

// Returns data from a list of objects of the specified metadata object as an XML string.
// 
// Parameters:
//  FullTableName - String - a name of the table that corresponds to the metadata object.
// 
// Returns:
//  String - an XML string of serialized presentation of the value table containing specified metadata object data.
//
Function GetTableObjects_2_0_1_6(FullTableName) Export
	
	Return DataExchangeServer.GetTableObjects(FullTableName);
	
EndFunction

// Returns specified properties (Synonym, Hierarchical) of a metadata object.
// 
// Parameters:
//  FullTableName - String - a name of the table that corresponds to the metadata object.
// 
// Returns:
//  SettingsStructure - Structure - metadata object properties.
//    * Synonym - String - a synonym.
//    * Hierarchical - String - the Hierarchical flag.
//
Function MetadataObjectProperties(FullTableName) Export
	
	Return DataExchangeServer.MetadataObjectProperties(FullTableName);
	
EndFunction

#EndRegion

#Region Internal

// Exports data for the infobase node to a temporary file.
// (For internal use only).
//
Procedure ExportForInfobaseNode(Cancel,
												ExchangePlanName,
												InfobaseNodeCode,
												FullNameOfExchangeMessageFile,
												ErrorMessageString = "") Export
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	If Common.FileInfobase() Then
		
		Try
			DataExchangeServer.ExportForInfobaseNodeViaFile(ExchangePlanName, InfobaseNodeCode, FullNameOfExchangeMessageFile);
		Except
			Cancel = True;
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
		EndTry;
		
	Else
		
		Address = "";
		
		Try
			
			DataExchangeServer.ExportToTempStorageForInfobaseNode(ExchangePlanName, InfobaseNodeCode, Address);
			
			GetFromTempStorage(Address).Write(FullNameOfExchangeMessageFile);
			
			DeleteFromTempStorage(Address);
			
		Except
			Cancel = True;
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
		EndTry;
		
	EndIf;
	
EndProcedure

// Records data exchange start in the event log.
// (For internal use only).
//
Procedure WriteLogEventDataExchangeStart(ExchangeSettingsStructure) Export
	
	DataExchangeServer.WriteLogEventDataExchangeStart(ExchangeSettingsStructure);
	
EndProcedure

// Records completion of data exchange via external connection.
// (For internal use only).
//
Procedure AddExchangeCompletionEventLogMessage(ExchangeSettingsStructureExternalConnection) Export
	
	ExchangeSettingsStructureExternalConnection.ExchangeExecutionResult = Enums.ExchangeExecutionResults[ExchangeSettingsStructureExternalConnection.ExchangeExecutionResultString];
	
	DataExchangeServer.AddExchangeOverExternalConnectionFinishEventLogMessage(ExchangeSettingsStructureExternalConnection);
	
EndProcedure

// Gets read object conversion rules by the exchange plan name.
// (For internal use only).
//
//  Returns:
//  Read object conversion rules.
//
Function GetObjectConversionRules(ExchangePlanName, GetCorrespondentRules = False) Export
	
	Return DataExchangeServer.GetObjectConversionRulesViaExternalConnection(ExchangePlanName, GetCorrespondentRules);
	
EndFunction

// Receives the structure of exchange settings.
// (For internal use only).
//
Function ExchangeSettingsStructure(Structure) Export
	
	Return DataExchangeServer.ExchangeOverExternalConnectionSettingsStructure(DataExchangeEvents.CopyStructure(Structure));
	
EndFunction

// Checks if the exchange plan with the specified name exists.
// (For internal use only).
//
Function ExchangePlanExists(ExchangePlanName) Export
	
	Return Metadata.ExchangePlans.Find(ExchangePlanName) <> Undefined;
	
EndFunction

// Gets the prefix of default infobase via external connection.
// Wrapper of a function with the same name in the overridable module.
// (For internal use only).
//
Function DefaultInfobasePrefix() Export
	
	InfobasePrefix = Undefined;
	DataExchangeOverridable.OnDetermineDefaultInfobasePrefix(InfobasePrefix);
	
	Return InfobasePrefix;
	
EndFunction

// Checks whether it is necessary to check conversion rules for version differences.
//
Function WarnAboutExchangeRuleVersionMismatch(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	Return DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRuleVersionMismatch");
	
EndFunction

// Receives the flag of the FullRights role availability.
// (For internal use only).
//
Function RoleAvailableFullAccess() Export
	
	Return Users.IsFullUser(, True);
	
EndFunction

// Returns a name of a predefined exchange plan node.
// (For internal use only).
//
Function PredefinedExchangePlanNodeDescription(ExchangePlanName) Export
	
	Return DataExchangeServer.PredefinedExchangePlanNodeDescription(ExchangePlanName);
	
EndFunction

// Returns a code of a predefined exchange plan node.
// (For internal use only).
//
Function CodeOfPredefinedExchangePlanNode(ExchangePlanName) Export
	
	Return DataExchangeServer.CodeOfPredefinedExchangePlanNode(ExchangePlanName);
	
EndFunction

// For internal use.
//
Function GetCommonNodesData(Val ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return ValueToStringInternal(DataExchangeServer.DataForThisInfobaseNodeTabularSections(ExchangePlanName));
	
EndFunction

// For internal use.
//
Function GetCommonNodesData_2_0_1_6(Val ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return Common.ValueToXMLString(DataExchangeServer.DataForThisInfobaseNodeTabularSections(ExchangePlanName));
	
EndFunction

// For internal use.
//
Function GetInfobaseParameters(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	Return DataExchangeServer.GetInfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage);
	
EndFunction

// For internal use.
//
Function GetInfobaseParameters_2_0_1_6(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	Return DataExchangeServer.GetInfobaseParameters_2_0_1_6(ExchangePlanName, NodeCode, ErrorMessage);
	
EndFunction

#EndRegion
