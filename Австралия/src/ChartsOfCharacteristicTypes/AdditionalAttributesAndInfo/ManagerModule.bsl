#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns object attributes allowed to be edited using bench attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	AttributesToEdit = New Array;
	
	AttributesToEdit.Add("MultilineInputField");
	AttributesToEdit.Add("ValueFormTitle");
	AttributesToEdit.Add("ValueSelectionFormTitle");
	AttributesToEdit.Add("FormatProperties");
	AttributesToEdit.Add("Comment");
	AttributesToEdit.Add("ToolTip");
	
	Return AttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	Result = New Array;
	
	Result.Add("ValueType");
	Result.Add("Name");
	
	Return Result;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(Ref)
	|	OR NOT IsAdditionalInfo";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Property("IsAccessValueSelection") Then
		Parameters.Filter.Insert("IsAdditionalInfo", True);
	EndIf;
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Changes the property setting from the common property or common list of property values to a 
// separate property with separate value list.
//
Procedure ChangePropertySetting(Parameters, StorageAddress) Export
	
	Property            = Parameters.Property;
	CurrentPropertiesSet = Parameters.CurrentPropertiesSet;
	
	OpenProperty = Undefined;
	Lock = New DataLock;
	
	LockItem = Lock.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo");
	LockItem.SetValue("Ref", Property);
	
	LockItem = Lock.Add("Catalog.AdditionalAttributesAndInfoSets");
	LockItem.SetValue("Ref", CurrentPropertiesSet);
	
	LockItem = Lock.Add("Catalog.ObjectsPropertiesValues");
	LockItem = Lock.Add("Catalog.ObjectPropertyValueHierarchy");
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		PropertyObject = Property.GetObject();
		
		Query = New Query;
		If ValueIsFilled(PropertyObject.AdditionalValuesOwner) Then
			Query.SetParameter("Owner", PropertyObject.AdditionalValuesOwner);
			PropertyObject.AdditionalValuesOwner = Undefined;
			PropertyObject.Write();
		Else
			Query.SetParameter("Owner", Property);
			NewObject = CreateItem();
			FillPropertyValues(NewObject, PropertyObject, , "Parent");
			PropertyObject = NewObject;
			PropertyObject.PropertySet = CurrentPropertiesSet;
			If ValueIsFilled(PropertyObject.Name) Then
				PropertyObject.Name = PropertyObject.Name + "1";
			EndIf;
			PropertyObject.Write();
			
			PropertySetObject = CurrentPropertiesSet.GetObject();
			If PropertyObject.IsAdditionalInfo Then
				FoundRow = PropertySetObject.AdditionalInfo.Find(Property, "Property");
				If FoundRow = Undefined Then
					PropertySetObject.AdditionalInfo.Add().Property = PropertyObject.Ref;
				Else
					FoundRow.Property = PropertyObject.Ref;
					FoundRow.DeletionMark = False;
				EndIf;
			Else
				FoundRow = PropertySetObject.AdditionalAttributes.Find(Property, "Property");
				If FoundRow = Undefined Then
					PropertySetObject.AdditionalAttributes.Add().Property = PropertyObject.Ref;
				Else
					FoundRow.Property = PropertyObject.Ref;
					FoundRow.DeletionMark = False;
				EndIf;
			EndIf;
			PropertySetObject.Write();
		EndIf;
		
		OpenProperty = PropertyObject.Ref;
		
		OwnerMetadata = PropertyManagerInternal.SetPropertiesValuesOwnerMetadata(
			PropertyObject.PropertySet, False);
		
		If OwnerMetadata = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '???????????? ?????? ?????????????????? ?????????????????? ???????????????? %1.
				           |?????????? ?????????????? %2 ???? ???????????? ???? ?? ?????????? ???????????????????? ???????????????? ??????????????.'; 
				           |en = 'An error occurred upon changing settings of the %1 property.
				           |The %2 property set is not associated with any properties values owner.'; 
				           |pl = 'B????d podczas zmiany ustawie?? w??a??ciwo??ci %1.
				           |Zestaw w??a??ciwo??ci %2 nie jest powi??zany z ??adnym w??a??cicielem warto??ci w??a??ciwo??ci.';
				           |es_ES = 'Error al cambiar las configuraciones de la %1 propiedad.
				           |Conjunto de propiedades %2 no est?? asignado a ning??n propietario de valores de la propiedad.';
				           |es_CO = 'Error al cambiar las configuraciones de la %1 propiedad.
				           |Conjunto de propiedades %2 no est?? asignado a ning??n propietario de valores de la propiedad.';
				           |tr = '??zelli??in ayarlar??n?? de??i??tirirken bir hata olu??tu%1. 
				           |??zellikler k??mesi %2 herhangi bir ??zellik de??eri sahibi ile ili??kilendirilmez.';
				           |it = 'Si ?? verificato un errore durante la modifica alle impostazioni della propriet?? %1.
				           | Il set di propriet?? %2 non ?? associato a nessun proprietario di valori di propriet??.';
				           |de = 'Fehler beim ??ndern der Einstellungen der %1 Eigenschaft.
				           |Eigenschaftseinstellung %2 ist keinem Besitzer von Eigenschaftswerten zugeordnet.'"),
				Property,
				PropertyObject.PropertySet);
		EndIf;
		
		FullOwnerName = OwnerMetadata.FullName();
		ReferenceMap = New Map;
		
		HasAdditionalValues = PropertyManagerInternal.ValueTypeContainsPropertyValues(
			PropertyObject.ValueType);
		
		If HasAdditionalValues Then
			
			If PropertyObject.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
				CatalogName = "ObjectsPropertiesValues";
				IsFolder      = "Values.IsFolder";
			Else
				CatalogName = "ObjectPropertyValueHierarchy";
				IsFolder      = "False AS IsFolder";
			EndIf;
			
			Query.Text =
			"SELECT
			|	Values.Ref AS Ref,
			|	Values.Parent AS RefParent,
			|	Values.IsFolder,
			|	Values.DeletionMark,
			|	Values.Description,
			|	Values.Weight
			|FROM
			|	Catalog.ObjectsPropertiesValues AS Values
			|WHERE
			|	Values.Owner = &Owner
			|TOTALS BY
			|	Ref HIERARCHY";
			Query.Text = StrReplace(Query.Text, "ObjectsPropertiesValues", CatalogName);
			Query.Text = StrReplace(Query.Text, "Values.IsFolder", IsFolder);
			
			DataExported = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
			NewGroupsAndValues(DataExported.Rows, ReferenceMap, CatalogName, PropertyObject.Ref);
			
		ElsIf Property = PropertyObject.Ref Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '???????????? ?????? ?????????????????? ?????????????????? ???????????????? %1.
				           |?????? ???????????????? ???? ???????????????? ???????????????????????????? ????????????????.'; 
				           |en = 'An error occurred upon changing the %1 property setting.
				           |Value type does not contain additional values.'; 
				           |pl = 'B????d podczas zmiany ustawie?? %1 w??a??ciwo??ci.
				           |Typ warto??ci nie zawiera dodatkowych warto??ci.';
				           |es_ES = 'Error al cambiar las configuraciones de la %1 propiedad.
				           |Tipo de valor no contiene los valores adicionales.';
				           |es_CO = 'Error al cambiar las configuraciones de la %1 propiedad.
				           |Tipo de valor no contiene los valores adicionales.';
				           |tr = '??zelli??in ayarlar??n?? de??i??tirirken bir hata %1 olu??tu. 
				           | De??er t??r?? ek de??erleri i??ermiyor.';
				           |it = 'Si ?? verificato un errore durante la modifica dell''impostazione di propriet?? %1.
				           |Il tipo di valore non contiene valori aggiuntivi.';
				           |de = 'Fehler beim ??ndern der Einstellungen der %1 Eigenschaft. Der
				           |Werttyp enth??lt keine zus??tzlichen Werte.'"),
				Property);
		EndIf;
		
		If Property <> PropertyObject.Ref
		 OR ReferenceMap.Count() > 0 Then
			
			Lock = New DataLock;
			
			LockItem = Lock.Add("InformationRegister.AdditionalInfo");
			LockItem.SetValue("Property", Property);
			
			LockItem = Lock.Add("InformationRegister.AdditionalInfo");
			LockItem.SetValue("Property", PropertyObject.Ref);
			
			// If the original property is common, then get object set list (by each reference), and if the 
			// common property being replaced is included not only in the specified set, then add a new property 
			// and value.
			//
			// For original common properties, when owners of their values have several property sets, the 
			// procedure can be especially long as it requires set analysis for each owner object because of 
			// overriding of sets in the FillObjectPropertySets procedure of the 
			// PropertyManagementOverridable??common module.
			
			OwnerWithAdditionalAttributes = False;
			
			If PropertyManagerInternal.IsMetadataObjectWithAdditionalAttributes(OwnerMetadata) Then
				OwnerWithAdditionalAttributes = True;
				LockItem = Lock.Add(FullOwnerName);
			EndIf;
			
			Lock.Lock();
			
			EachOwnerObjectSetsAnalysisRequired = False;
			
			If Property <> PropertyObject.Ref Then
				
				PredefinedItemName = StrReplace(OwnerMetadata.FullName(), ".", "_");
				
				EachOwnerObjectSetsAnalysisRequired = Common.ObjectAttributeValue(
					"Catalog.AdditionalAttributesAndInfoSets." + PredefinedItemName, "IsFolder");
				
				// If the predefined item is missing in the infobase.
				If EachOwnerObjectSetsAnalysisRequired = Undefined Then 
					EachOwnerObjectSetsAnalysisRequired = False;
				EndIf;
				
			EndIf;
			
			If EachOwnerObjectSetsAnalysisRequired Then
				AnalysisQuery = New Query;
				AnalysisQuery.SetParameter("CommonProperty", Property);
				AnalysisQuery.SetParameter("NewPropertySet", PropertyObject.PropertySet);
				AnalysisQuery.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS PropertySets
				|WHERE
				|	PropertySets.Ref <> &NewPropertySet
				|	AND PropertySets.Ref IN(&AllSetsForObject)
				|	AND PropertySets.Property = &CommonProperty";
			EndIf;
			
			Query = New Query;
			
			If Property = PropertyObject.Ref Then
				// If the property is not changed (already separate), and only the list of additional values is 
				// common, then replace only additional values.
				Query.TempTablesManager = New TempTablesManager;
				
				ValueTable = New ValueTable;
				ValueTable.Columns.Add("Value", New TypeDescription(
					"CatalogRef." + CatalogName));
				
				For each KeyAndValue In ReferenceMap Do
					ValueTable.Add().Value = KeyAndValue.Key;
				EndDo;
				
				Query.SetParameter("ValueTable", ValueTable);
				
				Query.Text =
				"SELECT
				|	ValueTable.Value AS Value
				|INTO OldValues
				|FROM
				|	&ValueTable AS ValueTable
				|
				|INDEX BY
				|	Value";
				Query.Execute();
			EndIf;
			
			Query.SetParameter("Property", Property);
			AdditionalValuesTypes = New Map;
			AdditionalValuesTypes.Insert(Type("CatalogRef.ObjectsPropertiesValues"), True);
			AdditionalValuesTypes.Insert(Type("CatalogRef.ObjectPropertyValueHierarchy"), True);
			
			// Additional info replacement.
			
			If Property = PropertyObject.Ref Then
				// If the property is not changed (already separate), and only the list of additional values is 
				// common, then replace only additional values.
				Query.Text =
				"SELECT TOP 1000
				|	AdditionalInfo.Object
				|FROM
				|	InformationRegister.AdditionalInfo AS AdditionalInfo
				|		INNER JOIN OldValues AS OldValues
				|		ON (VALUETYPE(AdditionalInfo.Object) = TYPE(Catalog.ObjectsPropertiesValues))
				|			AND (NOT AdditionalInfo.Object IN (&ProcessedObjects))
				|			AND (AdditionalInfo.Property = &Property)
				|			AND AdditionalInfo.Value = OldValues.Value";
			Else
				// If the property is changed (common property becomes separate and additional values are copied), 
				// then replace the property and additional values.
				Query.Text =
				"SELECT TOP 1000
				|	AdditionalInfo.Object
				|FROM
				|	InformationRegister.AdditionalInfo AS AdditionalInfo
				|WHERE
				|	VALUETYPE(AdditionalInfo.Object) = TYPE(Catalog.ObjectsPropertiesValues)
				|	AND NOT AdditionalInfo.Object IN (&ProcessedObjects)
				|	AND AdditionalInfo.Property = &Property";
			EndIf;
			
			Query.Text = StrReplace(Query.Text, "Catalog.ObjectsPropertiesValues", FullOwnerName);
			
			OldRecordSet = InformationRegisters.AdditionalInfo.CreateRecordSet();
			NewRecordSet  = InformationRegisters.AdditionalInfo.CreateRecordSet();
			NewRecordSet.Add();
			
			ProcessedObjects = New Array;
			
			While True Do
				Query.SetParameter("ProcessedObjects", ProcessedObjects);
				Selection = Query.Execute().Select();
				If Selection.Count() = 0 Then
					Break;
				EndIf;
				While Selection.Next() Do
					Replace = True;
					If EachOwnerObjectSetsAnalysisRequired Then
						AnalysisQuery.SetParameter("AllSetsForObject",
							PropertyManagerInternal.GetObjectPropertySets(
								Selection.Object).UnloadColumn("Set"));
						Replace = AnalysisQuery.Execute().IsEmpty();
					EndIf;
					OldRecordSet.Filter.Object.Set(Selection.Object);
					OldRecordSet.Filter.Property.Set(Property);
					OldRecordSet.Read();
					If OldRecordSet.Count() > 0 Then
						NewRecordSet[0].Object   = Selection.Object;
						NewRecordSet[0].Property = PropertyObject.Ref;
						Value = OldRecordSet[0].Value;
						If AdditionalValuesTypes[TypeOf(Value)] = Undefined Then
							NewRecordSet[0].Value = Value;
						Else
							NewRecordSet[0].Value = ReferenceMap[Value];
						EndIf;
						NewRecordSet.Filter.Object.Set(Selection.Object);
						NewRecordSet.Filter.Property.Set(NewRecordSet[0].Property);
						If Replace Then
							OldRecordSet.Clear();
							OldRecordSet.DataExchange.Load = True;
							OldRecordSet.Write();
						Else
							ProcessedObjects.Add(Selection.Object);
						EndIf;
						NewRecordSet.DataExchange.Load = True;
						NewRecordSet.Write();
					EndIf;
				EndDo;
			EndDo;
			
			// Additional attributes replacement.
			
			If OwnerWithAdditionalAttributes Then
				
				If EachOwnerObjectSetsAnalysisRequired Then
					AnalysisQuery = New Query;
					AnalysisQuery.SetParameter("CommonProperty", Property);
					AnalysisQuery.SetParameter("NewPropertySet", PropertyObject.PropertySet);
					AnalysisQuery.Text =
					"SELECT TOP 1
					|	TRUE AS TrueValue
					|FROM
					|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS PropertySets
					|WHERE
					|	PropertySets.Ref <> &NewPropertySet
					|	AND PropertySets.Ref IN(&AllSetsForObject)
					|	AND PropertySets.Property = &CommonProperty";
				EndIf;
				
				If Property = PropertyObject.Ref Then
					// If the property is not changed (already separate), and only the list of additional values is 
					// common, then replace only additional values.
					Query.Text =
					"SELECT TOP 1000
					|	CurrentTable.Ref AS Ref
					|FROM
					|	TableName AS CurrentTable
					|		INNER JOIN OldValues AS OldValues
					|		ON (NOT CurrentTable.Ref IN (&ProcessedObjects))
					|			AND (CurrentTable.Property = &Property)
					|			AND CurrentTable.Value = OldValues.Value";
				Else
					// If the property is changed (common property becomes separate and additional values are copied), 
					// then replace the property and additional values.
					Query.Text =
					"SELECT TOP 1000
					|	CurrentTable.Ref AS Ref
					|FROM
					|	TableName AS CurrentTable
					|WHERE
					|	NOT CurrentTable.Ref IN (&ProcessedObjects)
					|	AND CurrentTable.Property = &Property";
				EndIf;
				Query.Text = StrReplace(Query.Text, "TableName", FullOwnerName + ".AdditionalAttributes");
				
				ProcessedObjects = New Array;
				
				While True Do
					Query.SetParameter("ProcessedObjects", ProcessedObjects);
					Selection = Query.Execute().Select();
					If Selection.Count() = 0 Then
						Break;
					EndIf;
					While Selection.Next() Do
						CurrentObject = Selection.Ref.GetObject();
						Replace = True;
						If EachOwnerObjectSetsAnalysisRequired Then
							AnalysisQuery.SetParameter("AllSetsForObject",
								PropertyManagerInternal.GetObjectPropertySets(
									Selection.Ref).UnloadColumn("Set"));
							Replace = AnalysisQuery.Execute().IsEmpty();
						EndIf;
						For each Row In CurrentObject.AdditionalAttributes Do
							If Row.Property = Property Then
								Value = Row.Value;
								If AdditionalValuesTypes[TypeOf(Value)] <> Undefined Then
									Value = ReferenceMap[Value];
								EndIf;
								If Replace Then
									If Row.Property <> PropertyObject.Ref Then
										Row.Property = PropertyObject.Ref;
									EndIf;
									If Row.Value <> Value Then
										Row.Value = Value;
									EndIf;
								Else
									NewRow = CurrentObject.AdditionalAttributes.Add();
									NewRow.Property = PropertyObject.Ref;
									NewRow.Value = Value;
									ProcessedObjects.Add(CurrentObject.Ref);
									Break;
								EndIf;
							EndIf;
						EndDo;
						If CurrentObject.Modified() Then
							CurrentObject.DataExchange.Load = True;
							CurrentObject.Write();
						EndIf;
					EndDo;
				EndDo;
			EndIf;
			
			If Property = PropertyObject.Ref Then
				Query.TempTablesManager.Close();
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	PutToTempStorage(OpenProperty, StorageAddress);
	
EndProcedure

Procedure NewGroupsAndValues(Rows, ReferenceMap, CatalogName, Property, PreviousParent = Undefined)
	
	For each Row In Rows Do
		If Row.Ref = PreviousParent Then
			Continue;
		EndIf;
		
		If Row.IsFolder = True Then
			NewObject = Catalogs[CatalogName].CreateFolder();
			FillPropertyValues(NewObject, Row, "Description, DeletionMark");
		Else
			NewObject = Catalogs[CatalogName].CreateItem();
			FillPropertyValues(NewObject, Row, "Description, Weight, DeletionMark");
		EndIf;
		NewObject.Owner = Property;
		If ValueIsFilled(Row.RefParent) Then
			NewObject.Parent = ReferenceMap[Row.RefParent];
		EndIf;
		NewObject.Write();
		ReferenceMap.Insert(Row.Ref, NewObject.Ref);
		
		NewGroupsAndValues(Row.Rows, ReferenceMap, CatalogName, Property, Row.Ref);
	EndDo;
	
EndProcedure

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	AdditionalAttributesAndInfo.Ref AS Ref
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|WHERE
		|	AdditionalAttributesAndInfo.Name = &Name";
	Query.SetParameter("Name", "");
	
	Result = Query.Execute().Unload();
	RefsArray = Result.UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, RefsArray);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	FullName = "ChartOfCharacteristicTypes.AdditionalAttributesAndInfo";
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.PositionInQueue, FullName);
	
	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	While Selection.Next() Do
		
		BeginTransaction();
		Try
			// Locking the object for changes by other sessions.
			Lock = New DataLock;
			LockItem = Lock.Add(FullName);
			LockItem.SetValue("Ref", Selection.Ref);
			Lock.Lock();
			
			Object = Selection.Ref.GetObject();
			
			ObjectTitle = Object.Title;
			PropertyManagerInternal.DeleteDisallowedCharacters(ObjectTitle);
			ObjectTitleInParts = StrSplit(ObjectTitle, " ", False);
			For Each TitlePart In ObjectTitleInParts Do
				Object.Name = Object.Name + Upper(Left(TitlePart, 1)) + Mid(TitlePart, 2);
			EndDo;
			
			// Checking name for uniqueness.
			If NameUsed(Selection.Ref, Object.Name) Then
				UID = New UUID();
				UIDString = StrReplace(String(UID), "-", "");
				Object.Name = Object.Name + "_" + UIDString;
			EndIf;
			
			InfobaseUpdate.WriteData(Object);
			ObjectsProcessed = ObjectsProcessed + 1;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '???? ?????????????? ???????????????????? ???????????????????????????? ???????????????? (????????????????): %1 ???? ??????????????:
					|%2'; 
					|en = 'Cannot process additional attribute or information: %1 due to:
					|%2'; 
					|pl = 'Nie uda??o si?? przetworzy?? dodatkowego atrybutu lub informacji: %1 z powodu: 
					|%2';
					|es_ES = 'No se ha podido procesar el requisito adicional (informaci??n): %1 a causa de:
					|%2';
					|es_CO = 'No se ha podido procesar el requisito adicional (informaci??n): %1 a causa de:
					|%2';
					|tr = 'Ek alan (bilgi):%1 a??a????daki nedenle i??lenemedi: 
					|%2';
					|it = 'Impossibile elaborare l''attributo aggiuntivo o le informazioni: %1 a causa di:
					|%2';
					|de = 'Es war nicht m??glich, die zus??tzlichen Attribute (Zusammenfassung) zu bearbeiten: %1 wegen des Grundes:
					|%2'"), 
					Selection.Ref, DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
				Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo, Selection.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, FullName);
	If ObjectsProcessed = 0 AND ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???? ?????????????? ???????????????????? ?????????????????? ???????????????????????????? ?????????????????? ?????? ???????????????? (??????????????????): %1'; en = 'Cannot process some additional attributes or information (skipped): %1'; pl = 'Nie uda??o si?? przetworzy?? niekt??re dodatkowe atrybuty lub informacje (pomini??te): %1';es_ES = 'No se ha podido procesar unos requisitos adicionales o informaci??n (saltados): %1';es_CO = 'No se ha podido procesar unos requisitos adicionales o informaci??n (saltados): %1';tr = 'Baz?? ek alanlar veya bilgiler i??lenemedi (atland??): %1';it = 'Impossibile elaborare alcuni attributi aggiuntivi o informazioni (saltati): %1';de = 'Einige zus??tzliche Attribute oder Informationen konnten nicht verarbeitet werden (??bersprungen): %1'"), 
				ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo,,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '???????????????????? ?????????????????? ???????????? ???????????????????????????? ???????????????????? (????????????????): %1'; en = 'Another batch of additional attributes or information is processed: %1'; pl = 'Przetwarzana jest nast??pna porcja dodatkowych atrybut??w lub informacji: %1';es_ES = 'Se ha procesado unos requisitos adicionales (informaci??n): %1';es_CO = 'Se ha procesado unos requisitos adicionales (informaci??n): %1';tr = 'Ek alanlar??n (bilgilerin) s??radaki miktar?? i??lendi: %1';it = 'Elaborata un''altra porzione di requisiti (informazioni) aggiuntivi: %1';de = 'Die n??chste Charge der zus??tzlichen Attribute wurde bearbeitet (Informationen): %1'"),
					ObjectsProcessed));
	EndIf;
	
EndProcedure

Function NameUsed(Ref, Name)
	
	Query = New Query;
	Query.Text =
		"SELECT TOP 1
		|	Properties.IsAdditionalInfo,
		|	Properties.PropertySet
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
		|WHERE
		|	Properties.Name = &Name
		|	AND Properties.Ref <> &Ref";
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Name",    Name);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion

#EndIf