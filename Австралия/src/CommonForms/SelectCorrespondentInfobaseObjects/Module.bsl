
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Parameters.Property("ChoiceFoldersAndItems", ChoiceFoldersAndItems);
	
	PickMode = (Parameters.CloseOnChoice = False);
	AttributeName = Parameters.AttributeName;
	
	If Parameters.ExternalConnectionParameters.JoinType = "ExternalConnection" Then
		
		Connection = DataExchangeServer.ExternalConnectionToInfobase(Parameters.ExternalConnectionParameters);
		ErrorMessageString = Connection.DetailedErrorDescription;
		ExternalConnection       = Connection.Connection;
		
		If ExternalConnection = Undefined Then
			CommonClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
		MetadataObjectProperties = ExternalConnection.DataExchangeExternalConnection.MetadataObjectProperties(Parameters.CorrespondentInfobaseTableFullName);
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7
			OR Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			CorrespondentInfobaseTable = Common.ValueFromXMLString(ExternalConnection.DataExchangeExternalConnection.GetTableObjects_2_0_1_6(Parameters.CorrespondentInfobaseTableFullName));
			
		Else
			
			CorrespondentInfobaseTable = ValueFromStringInternal(ExternalConnection.DataExchangeExternalConnection.GetTableObjects(Parameters.CorrespondentInfobaseTableFullName));
			
		EndIf;
		
	ElsIf Parameters.ExternalConnectionParameters.JoinType = "WebService" Then
		
		ErrorMessageString = "";
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		ElsIf Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		Else
			
			WSProxy = DataExchangeServer.GetWSProxy(Parameters.ExternalConnectionParameters, ErrorMessageString);
			
		EndIf;
		
		If WSProxy = Undefined Then
			CommonClientServer.MessageToUser(ErrorMessageString,,,, Cancel);
			Return;
		EndIf;
		
		If Parameters.ExternalConnectionParameters.CorrespondentVersion_2_1_1_7
			OR Parameters.ExternalConnectionParameters.CorrespondentVersion_2_0_1_6 Then
			
			CorrespondentInfobaseData = XDTOSerializer.ReadXDTO(WSProxy.GetIBData(Parameters.CorrespondentInfobaseTableFullName));
			
			MetadataObjectProperties = CorrespondentInfobaseData.MetadataObjectProperties;
			CorrespondentInfobaseTable = Common.ValueFromXMLString(CorrespondentInfobaseData.CorrespondentInfobaseTable);
			
		Else
			
			CorrespondentInfobaseData = ValueFromStringInternal(WSProxy.GetIBData(Parameters.CorrespondentInfobaseTableFullName));
			
			MetadataObjectProperties = ValueFromStringInternal(CorrespondentInfobaseData.MetadataObjectProperties);
			CorrespondentInfobaseTable = ValueFromStringInternal(CorrespondentInfobaseData.CorrespondentInfobaseTable);
			
		EndIf;
		
	ElsIf Parameters.ExternalConnectionParameters.JoinType = "TemporaryStorage" Then
		TempStorageData = GetFromTempStorage(Parameters.ExternalConnectionParameters.TempStorageAddress);
		CorrespondentInfobaseData = TempStorageData.Get().Get(Parameters.CorrespondentInfobaseTableFullName);
		
		MetadataObjectProperties = CorrespondentInfobaseData.MetadataObjectProperties;
		CorrespondentInfobaseTable = Common.ValueFromXMLString(CorrespondentInfobaseData.CorrespondentInfobaseTable);
		
	EndIf;
	
	UpdateItemsIconsIndexes(CorrespondentInfobaseTable);
	
	Title = MetadataObjectProperties.Synonym;
	
	Items.List.Representation = ?(MetadataObjectProperties.Hierarchical = True, TableRepresentation.HierarchicalList, TableRepresentation.List);
	
	TreeItemsCollection = List.GetItems();
	TreeItemsCollection.Clear();
	Common.FillFormDataTreeItemCollection(TreeItemsCollection, CorrespondentInfobaseTable);
	
	// Placing a mouse pointer in the value tree.
	If Not IsBlankString(Parameters.ChoiceInitialValue) Then
		
		RowID = 0;
		
		CommonClientServer.GetTreeRowIDByFieldValue("ID", RowID, TreeItemsCollection, Parameters.ChoiceInitialValue, False);
		
		Items.List.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	ValueChoiceProcessing();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SelectValue(Command)
	
	ValueChoiceProcessing();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ValueChoiceProcessing()
	CurrentData = Items.List.CurrentData;
	
	If CurrentData=Undefined Then 
		Return
	EndIf;
	
	// Calculating the group flag indirectly:
	//     0 - a group not marked for deletion.
	//     1 - a group marked for deletion.
	
	IsFolder = CurrentData.PictureIndex=0 Or CurrentData.PictureIndex=1;
	If (IsFolder AND ChoiceFoldersAndItems=FoldersAndItems.Items) 
		Or (Not IsFolder AND ChoiceFoldersAndItems=FoldersAndItems.Folders) Then
		Return;
	EndIf;
	
	Data = New Structure("Presentation, ID");
	FillPropertyValues(Data, CurrentData);
	
	Data.Insert("PickMode", PickMode);
	Data.Insert("AttributeName", AttributeName);
	
	NotifyChoice(Data);
EndProcedure

// This procedure ensures backward compatibility.
//
&AtServer
Procedure UpdateItemsIconsIndexes(CorrespondentInfobaseTable)
	
	For Index = -3 To -2 Do
		
		Filter = New Structure;
		Filter.Insert("PictureIndex", - Index);
		
		FoundIndexes = CorrespondentInfobaseTable.Rows.FindRows(Filter, True);
		
		For Each FoundIndex In FoundIndexes Do
			
			FoundIndex.PictureIndex = FoundIndex.PictureIndex + 1;
			
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion
