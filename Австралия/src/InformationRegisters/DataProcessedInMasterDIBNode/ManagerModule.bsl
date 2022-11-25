#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Fills in the register of updated data to pass to the subordinate DIB nodes.
//
// Parameters:
//  PositionInQueue - Number - the position in the queue for the current handler.
//  Data - Ref, Array, DataSet - data, by which you need to register changes.
//            Registration by the independent information register is not supported.
//  AdditionalParameters - Structure - see InfobaseUpdate.AdditionalProcessingMarkParameters. 
//
Procedure MarkProcessingCompletion(PositionInQueue, Data, AdditionalParameters) Export
	
	If (SessionParameters.UpdateHandlerParameters.ExecuteInMasterNodeOnly 
			AND Not StandardSubsystemsCached.DIBUsed())
			Or (Not SessionParameters.UpdateHandlerParameters.ExecuteInMasterNodeOnly
				AND Not StandardSubsystemsCached.DIBUsed("WithFilter"))
			Or SessionParameters.UpdateHandlerParameters.RunAlsoInSubordinateDIBNodeWithFilters Then
		Return;
	EndIf;
	
	DataType = TypeOf(Data);
	
	If DataType = Type("Array")
		AND Data.Count() = 0 Then
		Return;
	EndIf;
	
	If SessionParameters.UpdateHandlerParameters.ExecuteInMasterNodeOnly Then
		DIBNodes = StandardSubsystemsCached.DIBNodes();
	Else
		DIBNodes = StandardSubsystemsCached.DIBNodes("WithFilter");
	EndIf;
	
	If DIBNodes.Count() = 0 Then
		Return;
	EndIf;
	
	If AdditionalParameters.IsRegisterRecords
		Or AdditionalParameters.IsIndependentInformationRegister Then
		MetadataObjectID = Common.MetadataObjectID(AdditionalParameters.FullRegisterName);
	Else
		
		If DataType = Type("Array") Then
			MetadataObjectID = Undefined;
		Else
			MetadataObjectID = Common.MetadataObjectID(DataType);
		EndIf;
		
	EndIf;
	
	DataSet = CreateRecordSet();
	
	If ValueIsFilled(MetadataObjectID) Then
		DataSet.Filter.MetadataObject.Set(MetadataObjectID);
	EndIf;
	
	DataSet.Filter.PositionInQueue.Set(PositionInQueue);
	
	If AdditionalParameters.IsRegisterRecords Then
		AddDataToSet(DIBNodes, DataSet, Data);
	ElsIf AdditionalParameters.IsIndependentInformationRegister Then
		
		For Each StrTabl In Data Do
			
			DimensionValueStructure = New Structure;
			GUID                       = New UUID;
			
			DataSet.Filter.UniqueKey.Set(GUID);
			
			For Each FilterItem In Data.Columns Do
				DimensionValueStructure.Insert(FilterItem.Name, StrTabl[FilterItem.Name]);
			EndDo;
			
			For Each DIBNode In DIBNodes Do
				
				NewRow = DataSet.Add();
				
				NewRow.ExchangePlanNode                     = DIBNode.Value;
				NewRow.MetadataObject                    = MetadataObjectID;
				NewRow.UniqueKey                    = GUID;
				NewRow.PositionInQueue                             = PositionInQueue;
				NewRow.IndependentRegisterFiltersValues = New ValueStorage(DimensionValueStructure, New Deflation(9));
				
			EndDo;
			
			WriteSetWithoutStandardChangeRegistration(DataSet, DIBNodes);
			
			DataSet = CreateRecordSet();
			If ValueIsFilled(MetadataObjectID) Then
				DataSet.Filter.MetadataObject.Set(MetadataObjectID);
			EndIf;
			DataSet.Filter.PositionInQueue.Set(PositionInQueue);
			
		EndDo;
		
	Else
		If TypeOf(Data) <> Type("Array") Then
			
			MetadataObject = Metadata.FindByType(DataType);
			If Common.IsConstant(MetadataObject) Then
				Return;
			EndIf;
			
			If Common.IsInformationRegister(MetadataObject)
				AND MetadataObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
				
				DimensionValueStructure = New Structure;
				GUID                       = New UUID;
				
				DataSet.Filter.UniqueKey.Set(GUID);
				
				For Each FilterItem In Data.Filter Do
					DimensionValueStructure.Insert(FilterItem.Name, FilterItem.Value);
				EndDo;
				
				For Each DIBNode In DIBNodes Do
					
					NewRow = DataSet.Add();
					
					NewRow.ExchangePlanNode                     = DIBNode.Value;
					NewRow.MetadataObject                    = MetadataObjectID;
					NewRow.UniqueKey                    = GUID;
					NewRow.PositionInQueue                             = PositionInQueue;
					NewRow.IndependentRegisterFiltersValues = New ValueStorage(DimensionValueStructure, New Deflation(9));
					
				EndDo;
				
				WriteSetWithoutStandardChangeRegistration(DataSet, DIBNodes);
				Return;
				
			EndIf;
			
			AddDataToSet(DIBNodes, DataSet, Data, MetadataObject);
			
		Else
			
			AddDataToSet(DIBNodes, DataSet, Data, , PositionInQueue);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure AddDataToSet(DIBNodes, DataSet, Data, MetadataObject = Undefined, PositionInQueue = Undefined)
	
	If TypeOf(Data) = Type("Array") Then
		
		For Each ArrayRow In Data Do
			
			DataSet = CreateRecordSet();
			DataSet.Filter.Data.Set(ArrayRow);
			DataSet.Filter.PositionInQueue.Set(PositionInQueue);
			DataSet.Filter.MetadataObject.Set(Common.MetadataObjectID(TypeOf(ArrayRow)));
			
			For Each DIBNode In DIBNodes Do
				NewRow = DataSet.Add();
				
				NewRow.ExchangePlanNode  = DIBNode.Value;
				NewRow.MetadataObject = DataSet.Filter.MetadataObject.Value;
				NewRow.Data           = ArrayRow;
				NewRow.PositionInQueue          = DataSet.Filter.PositionInQueue.Value;
				
			EndDo;
			
			WriteSetWithoutStandardChangeRegistration(DataSet, DIBNodes);
			
		EndDo;
		
	Else
		
		Value = Undefined;
		
		If MetadataObject = Undefined Then
			MetadataObject = Metadata.FindByType(TypeOf(Data));
		EndIf;
		
		If Common.IsReference(TypeOf(Data)) Then
			Value = Data;
		ElsIf Common.IsRefTypeObject(MetadataObject) Then
			Value = Data.Ref;
		Else
			Value = Data.Filter.Recorder.Value;
		EndIf;
		
		DataSet.Filter.Data.Set(Value);
		
		If Not DataSet.Filter.MetadataObject.Use
			Or Not ValueIsFilled(DataSet.Filter.MetadataObject.Value) Then
			DataSet.Filter.MetadataObject.Set(Common.MetadataObjectID(TypeOf(Value)));
		EndIf;
		
		For Each DIBNode In DIBNodes Do
			
			NewRow = DataSet.Add();
			
			NewRow.ExchangePlanNode  = DIBNode.Value;
			NewRow.MetadataObject = DataSet.Filter.MetadataObject.Value;
			NewRow.Data           = Value;
			NewRow.PositionInQueue          = DataSet.Filter.PositionInQueue.Value;
			
		EndDo;
		
		WriteSetWithoutStandardChangeRegistration(DataSet, DIBNodes);
		
	EndIf;
	
EndProcedure

Procedure WriteSetWithoutStandardChangeRegistration(DataSet, DIBNodes)
	
	// Write a set, replacing the standard registration logic by your own.
	SetToRegister = CreateRecordSet();
	For Each FilterItem In DataSet.Filter Do
		SetToRegister.Filter[FilterItem.Name].Set(FilterItem.Value);
	EndDo;
	
	For Each ListItem In DIBNodes Do
		
		DIBNode = ListItem.Value;
		SetToRegister.Filter.ExchangePlanNode.Set(DIBNode);
		ExchangePlans.RecordChanges(DIBNode, SetToRegister);
		
	EndDo;
	
	DataSet.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	DataSet.Write();
	
EndProcedure

#EndRegion

#EndIf