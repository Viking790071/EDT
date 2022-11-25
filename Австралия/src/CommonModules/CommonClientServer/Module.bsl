////////////////////////////////////////////////////////////////////////////////
// Common client and server procedures and function for working with:
// - print forms
// - files
// - managed forms
// - email addresses
// - dynamic list filters
// - other.
//
////////////////////////////////////////////////////////////////////////////////

#Region Public

// Generates and displays the message that can relate to a form item.
// 
//
// Parameters:
//  UserMessageText - String - текст сообщения.
//  DataKey - AnyRef - the infobase record key or object that message refers to.
//  Field                       - String - a form attribute description.
//  DataPath - String - a data path (a path to a form attribute).
//  Cancel - Boolean - an output parameter. Always True.
//
// Example:
//
//  1. Showing the message associated with the object attribute near the managed form field
//  CommonClientServer.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "FieldInFormAttributeObject",
//   "Object");
//
//  An alternative variant of using in the object form module
//  CommonClientServer.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "Object.FieldInFormAttributeObject");
//
//  2. Showing a message for the form attribute, next to the managed form field:
//  CommonClientServer.MessageToUser(
//   NStr("en = 'Error message.'"), ,
//   "FormAttributeName");
//
//  3. To display a message associated with an infobase object:
//  CommonClientServer.MessageToUser(
//   NStr("en = 'Error message.'"), InfobaseObject, "Responsible person",,Cancel);
//
//  4. To display a message from a link to an infobase object:
//  CommonClientServer.MessageToUser(
//   NStr("en = 'Error message.'"), Reference, , , Cancel);
//
//  Scenarios of incorrect using:
//   1. Passing DataKey and DataPath parameters at the same time.
//   2. Passing a value of an illegal type to the DataKey parameter.
//   3. Specifying a reference without specifying a field (and/or a data path).
//
Procedure MessageToUser(
		Val MessageToUserText,
		Val DataKey = Undefined,
		Val Field = "",
		Val DataPath = "",
		Cancel = False) Export
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.Field = Field;
	
	IsObject = False;
	
#If NOT ThinClient AND NOT WebClient AND NOT MobileClient Then
	If DataKey <> Undefined
	   AND XMLTypeOf(DataKey) <> Undefined Then
		ValueTypeAsString = XMLTypeOf(DataKey).TypeName;
		IsObject = StrFind(ValueTypeAsString, "Object.") > 0;
	EndIf;
#EndIf
	
	If IsObject Then
		Message.SetData(DataKey);
	Else
		Message.DataKey = DataKey;
	EndIf;
	
	If NOT IsBlankString(DataPath) Then
		Message.DataPath = DataPath;
	EndIf;
		
	Message.Message();
	
	Cancel = True;
	
EndProcedure

// Adds the error to the error list that will be displayed to the user with the ShowErrorsToUser() 
// procedure.
// The procedure collects errors to a list, which can be processed before they displayed to users.
//  You can sort the error list alphabetically, remove doubles, or change the appearance (for 
// example, display errors as a spreadsheet document, unlike the MessageToUser method default appearance).
//
// Parameters:
//  Errors - Undefined - creates a list.
//                  - The default value for the initial procedure call.
//
//  ErrorField - String - the field value in the UserMessage object.
//                    If you want to include a row number, use placeholder %1.
//                    For example, "Object.TIN" or "Object.Users[%1].User".
//
//  SingleErrorText - String - the error text for scenarios when the collection contains only one 
//                    ErrorGroup. For example, NStr("en = 'User not selected.'").
//
//  ErrorGroup - Arbitrary - provides text for a single error or a group of errors. For example, for 
//                    the "Object.Users" name.
//                    If blank, provides the single error text by default.
//
//  RowNumber - Number - the row number to pass to ErrorField and in SeveralErrorText. The displayed 
//                    number is RowNumber + 1.
//
//  SeveralErrorsText - String - the error text for scenarios when the collection contains a number 
//                    of errors with the same ErrorGroup property. For example, NStr("en = 'User on row %1 not selected.'").
//
//  RowIndex - Undefined - the same as the RowNumber parameter.
//                    Number - the number to pass to ErrorField. 
//                    
//
Procedure AddUserError(Errors, ErrorField, SingleErrorText, ErrorsGroup, RowNumber = 0, SeveralErrorsText = "", RowIndex = Undefined) Export
	
	If Errors = Undefined Then
		Errors = New Structure;
		Errors.Insert("ErrorsList", New Array);
		Errors.Insert("ErrorGroups", New Map);
	EndIf;
	
	If NOT ValueIsFilled(ErrorsGroup) Then
		// If the error group is empty, the single error text must be used.
	Else
		If Errors.ErrorGroups[ErrorsGroup] = Undefined Then
			// The error group has been used only once, the single error text must be used.
			Errors.ErrorGroups.Insert(ErrorsGroup, False);
		Else
			// The error group has been used several times, the several error text must be used.
			Errors.ErrorGroups.Insert(ErrorsGroup, True);
		EndIf;
	EndIf;
	
	Error = New Structure;
	Error.Insert("ErrorField",               ErrorField);
	Error.Insert("SingleErrorText",      SingleErrorText);
	Error.Insert("ErrorsGroup",             ErrorsGroup);
	Error.Insert("LineNumber",              RowNumber);
	Error.Insert("SeveralErrorsText", SeveralErrorsText);
	Error.Insert("RowIndex",             RowIndex);
	
	Errors.ErrorsList.Add(Error);
	
EndProcedure

// Displays errors accumulated by the AddUserError method. Different error text templates are used 
// depending on the number of errors of the same type.
//
// Parameters:
//  Errors - Undefined, Structure - an error collection.
//  Cancel - Boolean - True, if errors have been reported.
//
Procedure ReportErrorsToUser(Errors, Cancel = False) Export
	
	If Errors = Undefined Then
		Return;
	Else
		Cancel = True;
	EndIf;
	
	For each Error In Errors.ErrorsList Do
		
		If Error.RowIndex = Undefined Then
			RowIndex = Error.LineNumber;
		Else
			RowIndex = Error.RowIndex;
		EndIf;
		
		If Errors.ErrorGroups[Error.ErrorsGroup] <> True Then
			
			MessageToUser(
				Error.SingleErrorText,
				,
				StrReplace(Error.ErrorField, "%1", Format(RowIndex, "NZ=0; NG=")));
		Else
			MessageToUser(
				StrReplace(Error.SeveralErrorsText, "%1", Format(Error.LineNumber + 1, "NZ=0; NG=")),
				,
				StrReplace(Error.ErrorField, "%1", Format(RowIndex, "NZ=0; NG=")));
		EndIf;
	EndDo;
	
EndProcedure

// Generates a filling error text for fields and lists.
//
// Parameters:
//  FieldKind - String - can take the following values:
//                  Field, Column, List.
//  MessageKind - String - can take the following values:
//                  FillType, Correctness.
//  FieldName - String - a field name.
//  RowNumber - String, Number - a string number.
//  ListName - String - a list name.
//  MessageText - String - the detailed filling error description.
//
// Returns:
//   String - the filling error text.
//
Function FillingErrorText(FieldKind = "Field", MessageKind = "FillType",
	FieldName = "", RowNumber = "", ListName = "", MessageText = "") Export

	If Upper(FieldKind) = "FIELD" Then
		If Upper(MessageKind) = "FILLTYPE" Then
			Template = NStr("ru = 'Поле ""%1"" не заполнено'; en = 'Field ""%1"" is blank.'; pl = 'Pole ""%1"" nie jest wypełnione';es_ES = 'El ""%1"" campo no está rellenado';es_CO = 'El ""%1"" campo no está rellenado';tr = '""%1"" alanı doldurulmadı.';it = 'Il campo ""%1"" è vuoto.';de = 'Das Feld ""%1"" ist nicht ausgefüllt'");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Template = NStr("ru = 'Поле ""%1"" заполнено некорректно.
								|%4'; 
								|en = 'Invalid value of ""%1"" field.
								|%4'; 
								|pl = 'Pole ""%1"" jest wypełnione niepoprawnie.
								|%4';
								|es_ES = 'El campo ""%1"" está rellenado incorrectamente.
								|%4';
								|es_CO = 'El campo ""%1"" está rellenado incorrectamente.
								|%4';
								|tr = '""%1"" alanı yanlış dolduruldu. 
								|%4';
								|it = 'Valore non valido del campo ""%1"".
								|%4';
								|de = 'Das Feld ""%1"" ist nicht korrekt ausgefüllt.
								|%4'");
		EndIf;
	ElsIf Upper(FieldKind) = "COLUMN" Then
		If Upper(MessageKind) = "FILLTYPE" Then
			Template = NStr("ru = 'Не заполнена колонка ""%1"" в строке %2 списка ""%3""'; en = 'The ""%1"" column in line #%2 of the ""%3"" list is required.'; pl = 'Nie jest wypełniona kolumna ""%1"" w wierszu %2 listy ""%3""';es_ES = 'Columna ""%1"" no está rellenada en la línea %2 de la lista ""%3""';es_CO = 'Columna ""%1"" no está rellenada en la línea %2 de la lista ""%3""';tr = 'Sütun ""%1"" ""%2"" listesinin %3 satırında doldurulmadı';it = 'La colonna ""%1"" nella linea #%2 dell''elenco ""%3"" è richiesta.';de = 'Spalte ""%1"" wird nicht in der Reihe %2 der Liste ""%3"" ausgefüllt'");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Template = NStr("ru = 'Некорректно заполнена колонка ""%1"" в строке %2 списка ""%3"".
								|%4'; 
								|en = 'The ""%1"" column in line #%2 of the ""%3"" list contains invalid data.
								|%4'; 
								|pl = 'Niepoprawnie jest wypełniona kolumna ""%1"" w wierszu %2 listy ""%3"".
								|%4';
								|es_ES = 'La columna ""%1"" está rellenada incorrectamente en la línea %2 de la lista ""%3"".
								|%4';
								|es_CO = 'La columna ""%1"" está rellenada incorrectamente en la línea %2 de la lista ""%3"".
								|%4';
								|tr = 'Sütun%1, ""%2"" listenin %4 satırında yanlış dolduruldu%3
								|';
								|it = 'La colonna ""%1"" nella linea #%2 dell''elenco ""%3"" contiene dati non validi.
								|%4';
								|de = 'Falsch ausgefüllte Spalte ""%1"" in der Zeile %2 der Liste ""%3"".
								|%4'");
		EndIf;
	ElsIf Upper(FieldKind) = "LIST" Then
		If Upper(MessageKind) = "FILLTYPE" Then
			Template = NStr("ru = 'Не введено ни одной строки в список ""%3""'; en = 'The list ""%3"" is blank.'; pl = 'Do listy ""%3"" nie został wprowadzony żaden wiersz';es_ES = 'No hay líneas introducidas para la lista ""%3""';es_CO = 'No hay líneas introducidas para la lista ""%3""';tr = '""%3"" listesine herhangi satır girilmedi';it = 'L''elenco ""%3"" è vuoto.';de = 'Keine Linien eingegeben zur Liste ""%3""'");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Template = NStr("ru = 'Некорректно заполнен список ""%3"".
								|%4'; 
								|en = 'The list ""%3"" contains invalid data.
								|%4'; 
								|pl = 'Niepoprawnie jest wypełniona lista ""%3"".
								|%4';
								|es_ES = 'La lista ""%3"" está rellenada incorrectamente.
								|%4';
								|es_CO = 'La lista ""%3"" está rellenada incorrectamente.
								|%4';
								|tr = 'Liste%3 yanlış dolduruldu.
								|%4';
								|it = 'Elenco ""%3""compilato incorrettamente.
								|%4';
								|de = 'Liste ""%3""falsch ausgefüllt.
								|%4'");
		EndIf;
	EndIf;

	Return StringFunctionsClientServer.SubstituteParametersToString(Template, FieldName, RowNumber, ListName, MessageText);

EndFunction

// Generates a path to the LineNumber row and the AttributeName column of the TabularSectionName 
// tabular section to display messages on the form.
// This procedure is for using with the MessageToUser procedure (for passing values to the Field 
// parameter or to the DataPath parameter).
//
// Parameters:
//  TabularSectionName - String - a tabular section name.
//  RowNumber - Number - a tabular part row number.
//  AttributeName - String - an attribute name.
//
// Returns:
//  Row - the path to a table row.
//
Function PathToTabularSection(Val TabularSectionName, Val RowNumber, 
	Val AttributeName) Export

	Return TabularSectionName + "[" + Format(RowNumber - 1, "NZ=0; NG=0") + "]." + AttributeName;

EndFunction

// Supplements the destination value table with data from the source value table.
//
// Parameters:
//  SourceTable - ValueTable -  the table that provides rows.
//  DestinationTable - ValueTable - the table that receives rows from the source table.
//  
Procedure SupplementTable(SourceTable, DestinationTable) Export
	
	For Each SourceTableRow In SourceTable Do
		
		FillPropertyValues(DestinationTable.Add(), SourceTableRow);
		
	EndDo;
	
EndProcedure

// Supplements the Table value table with values from the Array array.
//
// Parameters:
//  Table - ValueTable - the table to be filled in with values from an array.
//  Array - Array - an array of values to provide for the table.
//  FieldName - String - the name of the value table field that receives the array values.
// 
Procedure SupplementTableFromArray(Table, Array, FieldName) Export

	For each Value In Array Do
		
		Table.Add()[FieldName] = Value;
		
	EndDo;
	
EndProcedure

// Supplements the DestinationArray array with values from the SourceArray array.
//
// Parameters:
//  DestinationArray - Array - the array that receives values.
//  SourceArray - Array - the array that provides values.
//  UniqueValuesOnly - Boolean - if True, the array keeps only unique values.
//
Procedure SupplementArray(DestinationArray, SourceArray, UniqueValuesOnly = False) Export
	
	If UniqueValuesOnly Then
		
		UniqueValues = New Map;
		
		For Each Value In DestinationArray Do
			UniqueValues.Insert(Value, True);
		EndDo;
		
		For Each Value In SourceArray Do
			If UniqueValues[Value] = Undefined Then
				DestinationArray.Add(Value);
				UniqueValues.Insert(Value, True);
			EndIf;
		EndDo;
		
	Else
		
		For Each Value In SourceArray Do
			DestinationArray.Add(Value);
		EndDo;
		
	EndIf;
	
EndProcedure

// Supplies the structure with the values from the other structure.
//
// Parameters:
//   Destination - Structure - the collection that receives new values.
//   Source - Structure - the collection that provides key-value pairs.
//   Replace - Boolean, Undefined - describes the behavior when the source and destination keys collide:
//                                       True - replace the source value. The fastest option.
//                                       False - do not replace the source value (skip it).
//                                       Undefined - the default value. Raise an exception.
//
Procedure SupplementStructure(Destination, Source, Replace = Undefined) Export
	
	For Each Item In Source Do
		If Replace <> True AND Destination.Property(Item.Key) Then
			If Replace = False Then
				Continue;
			Else
				Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Пересечение ключей источника и приемника: ""%1"".'; en = 'The source and destination have identical keys: ""%1"".'; pl = 'Przecięcie kluczy źródła i odbiornika: ""%1"".';es_ES = 'El cruce de las claves de la fuente y del receptor: ""%1"".';es_CO = 'El cruce de las claves de la fuente y del receptor: ""%1"".';tr = 'Kaynak ve alıcı anahtarlarının kesişimi: ""%1""';it = 'Sovrapposizione delle chiavi di fonte della destinazione: ""%1"".';de = 'Überschneidung der Quell- und Zielschlüssel: ""%1"".'"), Item.Key);
			EndIf
		EndIf;
		Destination.Insert(Item.Key, Item.Value);
	EndDo;
	
EndProcedure

// Complete a map with values from another map.
//
// Parameters:
//   Destination - Map - the collection that receives new values.
//   Source - Map - the collection that provides key-value pairs.
//   Replace - Boolean, Undefined - describes the behavior when the source and destination keys collide:
//                                       True - replace the source value. The fastest option.
//                                       False - do not replace the source value (skip it).
//                                       Undefined - the default value. Raise an exception.
//
Procedure SupplementMap(Destination, Source, Replace = Undefined) Export
	
	For Each Item In Source Do
		If Replace <> True AND Destination[Item.Key] <> Undefined Then
			If Replace = False Then
				Continue;
			Else
				Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Пересечение ключей источника и приемника: ""%1"".'; en = 'The source and destination have identical keys: ""%1"".'; pl = 'Przecięcie kluczy źródła i odbiornika: ""%1"".';es_ES = 'El cruce de las claves de la fuente y del receptor: ""%1"".';es_CO = 'El cruce de las claves de la fuente y del receptor: ""%1"".';tr = 'Kaynak ve alıcı anahtarlarının kesişimi: ""%1""';it = 'Sovrapposizione delle chiavi di fonte e della destinazione: ""%1"".';de = 'Überschneidung der Quell- und Zielschlüssel: ""%1"".'"), Item.Key);
			EndIf
		EndIf;
		Destination.Insert(Item.Key, Item.Value);
	EndDo;
	
EndProcedure

// Checks whether an arbitrary object has the attribute or property without metadata call.
//
// Parameters:
//  Object - Arbitrary - the object whose attribute or property you need to check.
//  AttributeName - String - the attribute or property name.
//
// Returns:
//  Boolean - True if the attribute is found.
//
Function HasAttributeOrObjectProperty(Object, AttributeName) Export
	
	UniqueKey   = New UUID;
	AttributeStructure = New Structure(AttributeName, UniqueKey);
	FillPropertyValues(AttributeStructure, Object);
	
	Return AttributeStructure[AttributeName] <> UniqueKey;
	
EndFunction

// Removes one conditional appearance item if this is a value list.
// 
// Parameters:
//  ConditionalAppearance - ConditionalAppearance - the form item conditional appearance.
//  UserSettingID - String - the setting ID.
//  Value - Arbitrary - the value to remove from the appearance list.
//
Procedure RemoveValueListConditionalAppearance(ConditionalAppearance, Val UserSettingID, 
	Val Value) Export
	
	For each ConditionalAppearanceItem In ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = UserSettingID Then
			If ConditionalAppearanceItem.Filter.Items.Count() = 0 Then
				Return;
			EndIf;
			ItemFilterList = ConditionalAppearanceItem.Filter.Items[0];
			If ItemFilterList.RightValue = Undefined Then
				Return;
			EndIf;
			ListItem = ItemFilterList.RightValue.FindByValue(Value);
			If ListItem <> Undefined Then
				ItemFilterList.RightValue.Delete(ListItem);
			EndIf;
			ItemFilterList.RightValue = ItemFilterList.RightValue;
			Return;
		EndIf;
	EndDo;
	
EndProcedure

// Deletes all occurrences of the passed value from the array.
//
// Parameters:
//  Array - Array - the array that contains a value to delete.
//  Value - Arbitrary - the array value to delete.
// 
Procedure DeleteAllValueOccurrencesFromArray(Array, Value) Export
	
	CollectionItemCount = Array.Count();
	
	For ReverseIndex = 1 To CollectionItemCount Do
		
		Index = CollectionItemCount - ReverseIndex;
		
		If Array[Index] = Value Then
			
			Array.Delete(Index);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Deletes all occurrences of specified type values.
//
// Parameters:
//  Array - Array - the array that contains values to delete.
//  Type - Type - the type of values to be deleted.
// 
Procedure DeleteAllTypeOccurrencesFromArray(Array, Type) Export
	
	CollectionItemCount = Array.Count();
	
	For ReverseIndex = 1 To CollectionItemCount Do
		
		Index = CollectionItemCount - ReverseIndex;
		
		If TypeOf(Array[Index]) = Type Then
			
			Array.Delete(Index);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Deletes one value from the array.
//
// Parameters:
//  Array - Array - the array that contains a value to delete.
//  Value - Array - the array value to delete.
// 
Procedure DeleteValueFromArray(Array, Value) Export
	
	Index = Array.Find(Value);
	
	If Index <> Undefined Then
		
		Array.Delete(Index);
		
	EndIf;
	
EndProcedure

// Deletes duplicate elements from the array.
//
// Parameters:
//  Array - Array - an array of values.
//
// Returns:
//  Array - a collection of unique elements.
//
Function CollapseArray(Array) Export
	Result = New Array;
	SupplementArray(Result, Array, True);
	Return Result;
EndFunction

// Fills the destination collection with values from the source collection.
// Objects of the following types can be a destination collection and a source collection:
// ValueTable, ValueTree, ValueList, and other collection types.
//
// Parameters:
//  SourceCollection - ArbitraryCollection - the collection that provides data.
//  DestinationCollection - ArbitraryCollection - the collection that receives data.
// 
Procedure FillPropertyCollection(SourceCollection, DestinationCollection) Export
	
	For Each Item In SourceCollection Do
		
		FillPropertyValues(DestinationCollection.Add(), Item);
		
	EndDo;
	
EndProcedure

// Gets an array of values containing marked items of the value list.
//
// Parameters:
//  List - ValueList - the list that provides values to form an array.
// 
// Returns:
//  Array - an array formed from the list items.
//
Function MarkedItems(List) Export
	
	// Function return value.
	Array = New Array;
	
	For Each Item In List Do
		
		If Item.Check Then
			
			Array.Add(Item.Value);
			
		EndIf;
		
	EndDo;
	
	Return Array;
EndFunction

// Calculates the difference between arrays. The difference between array A and array B is an array 
// that contains all elements from array A that are not present in array B.
//
// Parameters:
//  Array - Array - an array to subtract from.
//  SubtractionArray - Array - an array being subtracted.
// 
// Returns:
//  Array - the difference between array A and B.
//
// Example:
//	//A = [1, 3, 5, 7];
//	//B = [3, 7, 9];
//	Result = ArraysDifference(А, В);
//	//Result = [1, 5];
//
Function ArraysDifference(Array, SubtractionArray) Export
	
	Result = New Array;
	
	For Each Item In Array Do
		
		If SubtractionArray.Find(Item) = Undefined Then
			
			Result.Add(Item);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Converts JobSchedule into a structure.
//
// Parameters:
//  Schedule - JobSchedule - a source schedule.
// 
// Returns:
//  Structure - the schedule in the form of structure.
//
Function ScheduleToStructure(Val Schedule) Export
	
	ScheduleValue = Schedule;
	If ScheduleValue = Undefined Then
		ScheduleValue = New JobSchedule();
	EndIf;
	FieldsList = "CompletionTime,EndTime,BeginTime,EndDate,BeginDate,DayInMonth,WeekDayInMonth,"
		+ "WeekDays,CompletionInterval,Months,RepeatPause,WeeksPeriod,RepeatPeriodInDay,DaysRepeatPeriod";
	Result = New Structure(FieldsList);
	FillPropertyValues(Result, ScheduleValue, FieldsList);
	DetailedDailySchedules = New Array;
	For each DailySchedule In Schedule.DetailedDailySchedules Do
		DetailedDailySchedules.Add(ScheduleToStructure(DailySchedule));
	EndDo;
	Result.Insert("DetailedDailySchedules", DetailedDailySchedules);
	Return Result;
	
EndFunction

// Converts a structure intoJobSchedule.
//
// Parameters:
//  ScheduleStructure - Structure - the schedule in the form of structure.
// 
// Returns:
//  JobSchedule - a schedule.
//
Function StructureToSchedule(Val ScheduleStructure) Export
	
	If ScheduleStructure = Undefined Then
		Return New JobSchedule();
	EndIf;
	FieldsList = "CompletionTime,EndTime,BeginTime,EndDate,BeginDate,DayInMonth,WeekDayInMonth,"
		+ "WeekDays,CompletionInterval,Months,RepeatPause,WeeksPeriod,RepeatPeriodInDay,DaysRepeatPeriod";
	Result = New JobSchedule;
	FillPropertyValues(Result, ScheduleStructure, FieldsList);
	DetailedDailySchedules = New Array;
	For each Schedule In ScheduleStructure.DetailedDailySchedules Do
		DetailedDailySchedules.Add(StructureToSchedule(Schedule));
	EndDo;
	Result.DetailedDailySchedules = DetailedDailySchedules;  
	Return Result;
	
EndFunction

// Creates a complete recursive copy of a structure, map, array, list, or value table consistent 
// with the child item type. For object-type values (for example, CatalogObject or DocumentObject), 
// the procedure returns references to the source objects instead of copying the content.
//
// Parameters:
//  Source - Structure, Map, Array, ValueList, ValueTable - an object to copy.
//             
//
// Returns:
//  Structure, Map, Array, ValueList, ValueTable - the copy of an object passed in the Source parameter.
//
Function CopyRecursive(Source) Export
	
	Var Destination;
	
	SourceType = TypeOf(Source);
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If SourceType = Type("ValueTable") Then
		Return Source.Copy();
	EndIf;
#EndIf	
	If SourceType = Type("Structure") Then
		Destination = CopyStructure(Source);
	ElsIf SourceType = Type("Map") Then
		Destination = CopyMap(Source);
	ElsIf SourceType = Type("Array") Then
		Destination = CopyArray(Source);
	ElsIf SourceType = Type("ValueList") Then
		Destination = CopyValueList(Source);
	Else
		Destination = Source;
	EndIf;
	
	Return Destination;
	
EndFunction

// Creates a recursive copy of a Structure consistent with the property value types.
// For structure properties that contain object-type values (for example, CatalogObject or 
// DocumentObject), the procedure returns references to the source objects instead of copying the content.
//
// Parameters:
//  SourceStructure - Structure - a structure to copy.
// 
// Returns:
//  Structure - a copy of the source structure.
//
Function CopyStructure(SourceStructure) Export
	
	ResultingStructure = New Structure;
	
	For Each KeyAndValue In SourceStructure Do
		ResultingStructure.Insert(KeyAndValue.Key, CopyRecursive(KeyAndValue.Value));
	EndDo;
	
	Return ResultingStructure;
	
EndFunction

// Creates a recursive copy of a Map consistent with the value types.
// For map values that contain object-type values (for example, CatalogObject or DocumentObject), 
// the procedure returns references to the source objects instead of copying the content.
//
// Parameters:
//  SourceMap - Map - the map to copy.
// 
// Returns:
//  Map - a copy of the source map.
//
Function CopyMap(SourceMap) Export
	
	ResultingMap = New Map;
	
	For Each KeyAndValue In SourceMap Do
		ResultingMap.Insert(KeyAndValue.Key, CopyRecursive(KeyAndValue.Value));
	EndDo;
	
	Return ResultingMap;

EndFunction

// Creates a recursive copy of an Array consistent with the element value types.
// For array elements that contain object-type values (for example, CatalogObject or DocumentObject), 
// the procedure returns references to the source objects instead of copying the content.
//
// Parameters:
//  SourceArray - Array - the array to copy.
// 
// Returns:
//  Array - a copy of the source array.
//
Function CopyArray(SourceArray) Export
	
	ResultingArray = New Array;
	
	For Each Item In SourceArray Do
		ResultingArray.Add(CopyRecursive(Item));
	EndDo;
	
	Return ResultingArray;
	
EndFunction

// Creates a recursive copy of a ValueList consistent with the value types.
// For list of values that contain object-type values (for example, CatalogObject or DocumentObject), 
// the procedure returns references to the source objects instead of copying the content.
//
// Parameters:
//  SourceList - ValueList - the value list to copy.
// 
// Returns:
//  ValueList - a copy of the source value list.
//
Function CopyValueList(SourceList) Export
	
	ResultingList = New ValueList;
	
	For Each ListItem In SourceList Do
		ResultingList.Add(
			CopyRecursive(ListItem.Value), 
			ListItem.Presentation, 
			ListItem.Check, 
			ListItem.Picture);
	EndDo;
	
	Return ResultingList;
	
EndFunction

// Compares item values in two value list or element values in two arrays.
//
// Parameters:
//  List1 - Array, ValueList - the first item collection to compare.
//  List2 - Array, ValueList - the second item collection to compare.
//
// Returns:
//  Boolean - True if the collections are identical.
//
Function ValueListsAreEqual(List1, List2) Export
	
	ListsAreEqual = True;
	
	For Each ListItem1 In List1 Do
		If FindInList(List2, ListItem1) = Undefined Then
			ListsAreEqual = False;
			Break;
		EndIf;
	EndDo;
	
	If ListsAreEqual Then
		For Each ListItem2 In List2 Do
			If FindInList(List1, ListItem2) = Undefined Then
				ListsAreEqual = False;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return ListsAreEqual;
	
EndFunction

// Creates an array and adds the passed value to it.
//
// Parameters:
//  Value - Arbitrary - a value.
//
// Returns:
//  Array - a single-element array.
//
Function ValueInArray(Value) Export
	
	Array = New Array;
	Array.Add(Value);
	
	Return Array;
	
EndFunction

// Manages field states in a spreadsheet document.
//
// Parameters:
//  SpreadsheetDocumentField - FormField - a SpreadsheetDocumentField type form field that requires 
//                            the state change.
//  State - String - the state kind.
//
Procedure SetSpreadsheetDocumentFieldState(SpreadsheetDocumentField, State = "DontUse") Export
	
	If TypeOf(SpreadsheetDocumentField) = Type("FormField") 
		AND SpreadsheetDocumentField.Type = FormFieldType.SpreadsheetDocumentField Then
		StatePresentation = SpreadsheetDocumentField.StatePresentation;
		If Upper(State) = "DONTUSE" Then
			StatePresentation.Visible                      = False;
			StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
			StatePresentation.Picture                       = New Picture;
			StatePresentation.Text                          = "";
		ElsIf Upper(State) = "IRRELEVANCE" Then
			StatePresentation.Visible                      = True;
			StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
			StatePresentation.Picture                       = New Picture;
			StatePresentation.Text                          = NStr("ru = 'Отчет не сформирован. Нажмите ""Сформировать отчет"" для получения отчета.'; en = 'To run report, click ""Generate"".'; pl = 'Aby utworzyć raport, kliknij ""Wygeneruj raport"".';es_ES = 'Para generar el informe, haga clic en ""Generar informe"".';es_CO = 'Para generar el informe, haga clic en ""Generar informe"".';tr = 'Raporu çalıştırmak için ""Rapor oluştur""a tıklayın.';it = 'Per eseguire il report, cliccare su ""Genera report"".';de = 'Um den Bericht auszuführen, klicken Sie auf ""Bericht generieren"".'");;
		ElsIf Upper(State) = "REPORTGENERATION" Then  
			StatePresentation.Visible                      = True;
			StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
			StatePresentation.Picture                       = PictureLib.TimeConsumingOperation48;
			StatePresentation.Text                          = NStr("ru = 'Отчет формируется...'; en = 'Generating report...'; pl = 'Generowanie raportu...';es_ES = 'Generando el informe...';es_CO = 'Generando el informe...';tr = 'Rapor oluşturma...';it = 'Generazione report...';de = 'Den Bericht erstellen...'");
		Else
			Raise(NStr("ru = 'Недопустимое значение параметра (параметр номер ""2"")'; en = 'Invalid parameter value (parameter number: 2).'; pl = 'Nieprawidłowa wartość parametru (parametr nr 2)';es_ES = 'Valor del parámetro inválido (parámetro número 2)';es_CO = 'Valor del parámetro inválido (parámetro número 2)';tr = 'Geçersiz parametre değeri (parametre numarası 2)';it = 'Valore di parametro non valido (numero parametro ''2'')';de = 'Ungültiger Parameterwert (Parameternummer 2)'"));
		EndIf;
	Else
		Raise(NStr("ru = 'Недопустимое значение параметра (параметр номер ""1"")'; en = 'Invalid parameter value (parameter number: 1).'; pl = 'Nieprawidłowa wartość parametru (parametr nr 1)';es_ES = 'Valor del parámetro inválido (parámetro número 1)';es_CO = 'Valor del parámetro inválido (parámetro número 1)';tr = 'Geçersiz parametre değeri (parametre numarası 1)';it = 'Valore di parametro non valido (numero parametro ''1'')';de = 'Ungültiger Parameterwert (Parameternummer 1)'"));
	EndIf;
	
EndProcedure

// Gets the configuration version without the build version.
//
// Parameters:
//  Version - String - the configuration version in the RR.PP.ZZ.CC format, where CC is the build 
//                    version and excluded from the result.
// 
// Returns:
//  String - configuration version in the RR.PP.ZZ format, excluding the build version.
//
Function ConfigurationVersionWithoutBuildNumber(Val Version) Export
	
	Array = StrSplit(Version, ".");
	
	If Array.Count() < 3 Then
		Return Version;
	EndIf;
	
	Result = "[Edition].[Subedition].[Release]";
	Result = StrReplace(Result, "[Edition]",    Array[0]);
	Result = StrReplace(Result, "[Subedition]", Array[1]);
	Result = StrReplace(Result, "[Release]",       Array[2]);
	
	Return Result;
EndFunction

// Compares two versions in the String format.
//
// Parameters:
//  VersionString1  - String - the first version in the RR.{S|SS}.VV.BB format.
//  VersionString2  - String - the second version.
//
// Returns:
//   Number - if VersionString1 > VersionString2, it is a positive number. If they are equal, it is 0.
//
Function CompareVersions(Val VersionString1, Val VersionString2) Export
	
	String1 = ?(IsBlankString(VersionString1), "0.0.0.0", VersionString1);
	String2 = ?(IsBlankString(VersionString2), "0.0.0.0", VersionString2);
	Version1 = StrSplit(String1, ".");
	If Version1.Count() <> 4 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Неправильный формат параметра VersionString1: %1'; en = 'Invalid format of VersionString1 parameter: %1.'; pl = 'Niepoprawny format dla parametru VersionString1: %1';es_ES = 'Formato inválido para el parámetro VersiónFila1:%1';es_CO = 'Formato inválido para el parámetro VersiónFila1:%1';tr = 'VersionString1 parametresi için geçersiz biçim: %1.';it = 'Il formato del parametro RigaVersione1: %1 è incorretto.';de = 'Ungültiges Format für Parameter Version Reihe1: %1.'"), VersionString1);
	EndIf;
	Version2 = StrSplit(String2, ".");
	If Version2.Count() <> 4 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
	    	NStr("ru = 'Неправильный формат параметра VersionString2: %1'; en = 'Invalid format of VersionString2 parameter: %1.'; pl = 'Niepoprawny format dla parametru VersionString2: %1';es_ES = 'Formato inválido para el parámetro VersiónFila2:%1';es_CO = 'Formato inválido para el parámetro VersiónFila2:%1';tr = 'VersionString1 parametresi için geçersiz biçim: %1.';it = 'Il formato del parametro RigaVersione2: %1 è incorretto.';de = 'Ungültiges Format für Parameter Version Reihe2: %1.'"), VersionString2);
	EndIf;
	
	Result = 0;
	For Digit = 0 To 3 Do
		Result = Number(Version1[Digit]) - Number(Version2[Digit]);
		If Result <> 0 Then
			Return Result;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

// Compares two versions in the String format.
//
// Parameters:
//  VersionString1 - String - the first version in the RR.{P|PP}.ZZ format.
//  VersionString2  - String - the second version.
//
// Returns:
//   Number - if VersionString1 > VersionString2, it is a positive number. If they are equal, it is 0.
//
Function CompareVersionsWithoutBuildNumber(Val VersionString1, Val VersionString2) Export
	
	String1 = ?(IsBlankString(VersionString1), "0.0.0", VersionString1);
	String2 = ?(IsBlankString(VersionString2), "0.0.0", VersionString2);
	Version1 = StrSplit(String1, ".");
	If Version1.Count() <> 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Неправильный формат параметра VersionString1: %1'; en = 'Invalid format of VersionString1 parameter: %1.'; pl = 'Niepoprawny format dla parametru VersionString1: %1';es_ES = 'Formato inválido para el parámetro VersiónFila1:%1';es_CO = 'Formato inválido para el parámetro VersiónFila1:%1';tr = 'VersionString1 parametresi için geçersiz biçim: %1.';it = 'Il formato del parametro RigaVersione1: %1 è incorretto.';de = 'Ungültiges Format für Parameter Version Reihe1: %1.'"), VersionString1);
	EndIf;
	Version2 = StrSplit(String2, ".");
	If Version2.Count() <> 3 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
	    	NStr("ru = 'Неправильный формат параметра VersionString2: %1'; en = 'Invalid format of VersionString2 parameter: %1.'; pl = 'Niepoprawny format dla parametru VersionString2: %1';es_ES = 'Formato inválido para el parámetro VersiónFila2:%1';es_CO = 'Formato inválido para el parámetro VersiónFila2:%1';tr = 'VersionString2 parametresi için geçersiz biçim: %1.';it = 'Il formato del parametro RigaVersione2: %1 è incorretto.';de = 'Ungültiges Format für Parameter Version Reihe2: %1.'"), VersionString2);
	EndIf;
	
	Result = 0;
	For Digit = 0 To 2 Do
		Result = Number(Version1[Digit]) - Number(Version2[Digit]);
		If Result <> 0 Then
			Return Result;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

// Gets a string that contains delimiter-separated structure keys.
//
// Parameters:
//	Structure - Structure - a structure that contains keys to convert into a string.
//	Separator - String - the delimiter character.
//
// Returns:
//	String - the string that contains delimiter-separated structure keys.
//
Function StructureKeysToString(Structure, Separator = ",") Export
	
	Result = "";
	
	For Each Item In Structure Do
		SeparatorChar = ?(IsBlankString(Result), "", Separator);
		Result = Result + SeparatorChar + Item.Key;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns the structure property value.
//
// Parameters:
//   Structure - Structure, FixedStructure - an object to read key value from.
//   Key - String - the structure property whose value to read.
//   DefaultValue - Arbitrary - Optional. Returned when the structure contains no value for the 
//                                        given key.
//       To keep the system performance, it is recommended to pass only easy-to-calculate values 
//       (for example, primitive types). Pass performance-demanding values only after ensuring that 
//       the value is required.
//
// Returns:
//   Arbitrary - the property value. If the structure missing the property, returns DefaultValue.
//
Function StructureProperty(Structure, varKey, DefaultValue = Undefined) Export
	
	If Structure = Undefined Then
		Return DefaultValue;
	EndIf;
	
	Result = DefaultValue;
	If Structure.Property(varKey, Result) Then
		Return Result;
	Else
		Return DefaultValue;
	EndIf;
	
EndFunction

// Returns the name of the COM class to operate 1C:Enterprise over a COM connection.
//
// Returns:
//  Returns the name of the COM class to operate 1C:Enterprise over a COM connection.
//
Function COMConnectorName() Export
	SystemInfo = New SystemInfo;
	VersionSubstrings = StrSplit(SystemInfo.AppVersion, ".");
	Return "v" + VersionSubstrings[0] + VersionSubstrings[1] + ".COMConnector";
EndFunction

// Establishes an external infobase connection with the passed parameters and returns a pointer to 
// the connection.
// 
// Parameters:
//  Parameters - Structure - external connection parameters.
//                          For the properties, see function
//                          CommonClientServer.ParametersStructureForExternalConnection):
//
//    * InfobaseOperationMode - Number - the infobase operation mode. The file mode - 0. The 
//                                                            client/server mode - 1.
//    * InfobaseDirectory - String - the infobase directory.
//    * NameOf1CEnterpriseServer - String - the name of the 1C:Enterprise server.
//    * NameOfInfobaseOn1CEnterpriseServer - String - a name of the infobase on 1C Enterprise server.
//    * OperatingSystemAuthentication - Boolean - indicates whether the operating system is 
//                                                             authenticated on establishing a connection to the infobase.
//    * UserName - String - the name of an infobase user.
//    * UserPassword - String - the user password.
// 
//  ErrorMessageString - String - if establishing connection fails, this parameter will store the 
//                                     error details.
//  ErrorAttachingAddIn - Boolean - (a return parameter) True if add-in attachment failed.
//
// Returns:
//  COMObject, Undefined - if the external connection established, returns the COM object pointer.
//    Otherwise, returns Undefined.
//
Function EstablishExternalConnection(Parameters, ErrorMessageString = "", AddInAttachmentError = False) Export
	Result = EstablishExternalConnectionWithInfobase(Parameters);
	AddInAttachmentError = Result.AddInAttachmentError;
	ErrorMessageString     = Result.DetailedErrorDescription;
	
	Return Result.Connection;
EndFunction

// Establishes an external infobase connection with the passed parameters and returns a pointer to 
// the connection.
// 
// Parameters:
//  Parameters - Structure - external connection parameters.
//                          For the properties, see function
//                          CommonClientServer.ParametersStructureForExternalConnection):
//
//   * InfobaseOperationMode - Number - the infobase operation mode. The file mode - 0. The 
//                                                            client/server mode - 1.
//   * InfobaseDirectory - String - the infobase directory.
//   * NameOf1CEnterpriseServer - String - the name of the 1C:Enterprise server.
//   * NameOfInfobaseOn1CEnterpriseServer - String - a name of the infobase on 1C Enterprise server.
//   * OperatingSystemAuthentication - Boolean - indicates whether the operating system is 
//                                                            authenticated on establishing a connection to the infobase.
//   * UserName - String - the name of an infobase user.
//   * UserPassword - String - the user password.
// 
// Returns:
//  Structure - connection details:
//    * Connection - COMObject, Undefined - if the connection is established, returns a COM object 
//                                    reference. Otherwise, returns Undefined.
//    * BriefErrorDescription       - String - a brief error description.
//    * DetailedErrorDescription     - String - a detailed error description.
//    * ErrorAttachingAddIn - Boolean - a COM connection error flag.
//
Function EstablishExternalConnectionWithInfobase(Parameters) Export
	
	Result = New Structure;
	Result.Insert("Connection");
	Result.Insert("BriefErrorDescription", "");
	Result.Insert("DetailedErrorDescription", "");
	Result.Insert("AddInAttachmentError", False);
	
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		ConnectionUnavailable = Common.IsLinuxServer();
		BriefErrorDescription = NStr("ru = 'Прямое подключение к информационной базе недоступно на сервере под управлением ОС Linux.'; en = 'Direct infobase connection is not supported on Linux servers.'; pl = 'Bezpośrednie połączenie z bazą informacyjną na serwerze pod OS Linux nie jest dostępne.';es_ES = 'Conexión directa a la infobase en un servidor bajo OS Linux no está disponible.';es_CO = 'Conexión directa a la infobase en un servidor bajo OS Linux no está disponible.';tr = 'Linux OS kapsamında bir sunucudaki veritabanına doğrudan bağlantı mevcut değildir.';it = 'La connessione diretta all''infobase non è supportata sui server Linux.';de = 'Direkte Verbindung zur Infobase auf einem Server unter Betriebssystem Linux ist nicht verfügbar.'");
	#Else
		ConnectionUnavailable = IsLinuxClient() Or IsOSXClient();
		BriefErrorDescription = NStr("ru = 'Прямое подключение к информационной базе доступно только на клиенте под управлением ОС Windows.'; en = 'Direct infobase connection is available only on Windows clients.'; pl = 'Bezpośrednie podłączenie do bazy informacyjnej jest dostępne tylko dla klienta w systemie operacyjnym Windows.';es_ES = 'Conexión directa a la infobase solo está disponible en un cliente bajo OS Windows.';es_CO = 'Conexión directa a la infobase solo está disponible en un cliente bajo OS Windows.';tr = 'Windows OS kapsamında bir istemcideki veritabanına doğrudan bağlantı mevcut değildir.';it = 'La connessione diretta all''infobase è disponibile solo su client Windows.';de = 'Eine direkte Verbindung zur Informationsbasis ist nur auf dem Client mit dem Betriebssystem Windows möglich.'");
	#EndIf
	
	If ConnectionUnavailable Then
		Result.Connection = Undefined;
		Result.BriefErrorDescription = BriefErrorDescription;
		Result.DetailedErrorDescription = BriefErrorDescription;
		Return Result;
	EndIf;
	
	Try
		COMConnector = New COMObject(COMConnectorName()); // "V83.COMConnector"
	Except
		Information = ErrorInfo();
		ErrorMessageString = NStr("ru = 'Не удалось подключится к другой программе: %1'; en = 'Cannot connect to another application: %1'; pl = 'Nie można połączyć się z inną aplikacją: %1';es_ES = 'No se puede conectar a otra aplicación: %1';es_CO = 'No se puede conectar a otra aplicación: %1';tr = 'Başka bir uygulamaya bağlanılamıyor: %1';it = 'Non può essre collegato ad un altra applicazione: %1';de = 'Kann keine Verbindung zu einer anderen Anwendung herstellen: %1'");
		
		Result.AddInAttachmentError = True;
		Result.DetailedErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, DetailErrorDescription(Information));
		Result.BriefErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, BriefErrorDescription(Information));
		
		Return Result;
	EndTry;
	
	FileRunMode = Parameters.InfobaseOperatingMode = 0;
	
	// Checking parameter correctness.
	FillingCheckError = False;
	If FileRunMode Then
		
		If IsBlankString(Parameters.InfobaseDirectory) Then
			ErrorMessageString = NStr("ru = 'Не задано месторасположение каталога информационной базы.'; en = 'The infobase directory location is not specified.'; pl = 'Lokalizacja katalogu bazy informacyjnej nie jest określona.';es_ES = 'Ubicación del directorio de la infobase no está especificada.';es_CO = 'Ubicación del directorio de la infobase no está especificada.';tr = 'Veritabanın dizininin yeri belirlenmemiştir.';it = 'Non è indicata la posizione del catalogo del database.';de = 'Der Speicherort des Infobase-Verzeichnisses ist nicht angegeben.'");
			FillingCheckError = True;
		EndIf;
		
	Else
		
		If IsBlankString(Parameters.NameOf1CEnterpriseServer) Or IsBlankString(Parameters.NameOfInfobaseOn1CEnterpriseServer) Then
			ErrorMessageString = NStr("ru = 'Не заданы обязательные параметры подключения: ""Имя сервера""; ""Имя информационной базы на сервере"".'; en = 'Required connection parameters are not specified: server name and infobase name.'; pl = 'Wymagane parametry połączenia nie są określone: ""Nazwa serwera""; ""Nazwa bazy informacyjnej na serwerze"".';es_ES = 'Parámetros de conexión requeridos no están especificados: ""Nombre del servidor""; ""Nombre de la infobase en el servidor"".';es_CO = 'Parámetros de conexión requeridos no están especificados: ""Nombre del servidor""; ""Nombre de la infobase en el servidor"".';tr = 'Gerekli bağlantı parametreleri belirlenmemiş: ""Sunucu adı""; ""Sunucudaki veritabanın adı"".';it = 'I parametri di connessione obbligatori non sono impostati: ""Nome server""; ""Nome del database sul server"".';de = 'Erforderliche Verbindungsparameter sind nicht angegeben: ""Servername""; ""Name der Infobase auf dem Server"".'");
			FillingCheckError = True;
		EndIf;
		
	EndIf;
	
	If FillingCheckError Then
		
		Result.DetailedErrorDescription = ErrorMessageString;
		Result.BriefErrorDescription   = ErrorMessageString;
		Return Result;
		
	EndIf;
	
	// Generating the connection string.
	ConnectionStringPattern = "[InfobaseString][AuthenticationString]";
	
	If FileRunMode Then
		InfobaseString = "File = ""&InfobaseDirectory""";
		InfobaseString = StrReplace(InfobaseString, "&InfobaseDirectory", Parameters.InfobaseDirectory);
	Else
		InfobaseString = "Srvr = ""&NameOf1CEnterpriseServer""; Ref = ""&NameOfInfobaseOn1CEnterpriseServer""";
		InfobaseString = StrReplace(InfobaseString, "&NameOf1CEnterpriseServer",                     Parameters.NameOf1CEnterpriseServer);
		InfobaseString = StrReplace(InfobaseString, "&NameOfInfobaseOn1CEnterpriseServer", Parameters.NameOfInfobaseOn1CEnterpriseServer);
	EndIf;
	
	If Parameters.OperatingSystemAuthentication Then
		AuthenticationString = "";
	Else
		
		If StrFind(Parameters.UserName, """") Then
			Parameters.UserName = StrReplace(Parameters.UserName, """", """""");
		EndIf;
		
		If StrFind(Parameters.UserPassword, """") Then
			Parameters.UserPassword = StrReplace(Parameters.UserPassword, """", """""");
		EndIf;
		
		AuthenticationString = "; Usr = ""&UserName""; Pwd = ""&UserPassword""";
		AuthenticationString = StrReplace(AuthenticationString, "&UserName",    Parameters.UserName);
		AuthenticationString = StrReplace(AuthenticationString, "&UserPassword", Parameters.UserPassword);
	EndIf;
	
	ConnectionString = StrReplace(ConnectionStringPattern, "[InfobaseString]", InfobaseString);
	ConnectionString = StrReplace(ConnectionString, "[AuthenticationString]", AuthenticationString);
	
	Try
		Result.Connection = COMConnector.Connect(ConnectionString);
	Except
		Information = ErrorInfo();
		ErrorMessageString = NStr("ru = 'Не удалось подключится к другой программе: %1'; en = 'Cannot connect to another application: %1'; pl = 'Nie można połączyć się z inną aplikacją: %1';es_ES = 'No se puede conectar a otra aplicación: %1';es_CO = 'No se puede conectar a otra aplicación: %1';tr = 'Başka bir uygulamaya bağlanılamıyor: %1';it = 'Non può essre collegato ad un altra applicazione: %1';de = 'Kann keine Verbindung zu einer anderen Anwendung herstellen: %1'");
		
		Result.AddInAttachmentError = True;
		Result.DetailedErrorDescription     = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, DetailErrorDescription(Information));
		Result.BriefErrorDescription       = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, BriefErrorDescription(Information));
	EndTry;
	
	Return Result;
	
EndFunction

// Gets a picture to display on a page with a comment.
// 
//
// Parameters:
//  Comment - String - the comment text.
//
// Returns:
//  Picture - the picture to display on the comment page.
//
Function CommentPicture(Comment) Export

	If NOT IsBlankString(Comment) Then
		Picture = PictureLib.Comment;
	Else
		Picture = New Picture;
	EndIf;
	
	Return Picture;
	
EndFunction

// Convert a local date to the "YYYY-MM-DDThh:mm:ssTZD" format (ISO 8601).
//
// Parameters:
//  LocalDate - Date - a date in the session time zone.
// 
// Returns:
//   String - the date sting presentation.
//
Function LocalDatePresentationWithOffset(LocalDate) Export
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		Offset = StandardTimeOffset(SessionTimeZone());
	#Else
		Offset = StandardSubsystemsClient.ClientRunParameters().StandardTimeOffset;
	#EndIf
	OffsetPresentation = "Z";
	If Offset > 0 Then
		OffsetPresentation = "+";
	ElsIf Offset < 0 Then
		OffsetPresentation = "-";
		Offset = -Offset;
	EndIf;
	If Offset <> 0 Then
		OffsetPresentation = OffsetPresentation + Format('00010101' + Offset, "DF=HH:mm");
	EndIf;
	
	Return Format(LocalDate, "DF=yyyy-MM-ddTHH:mm:ss; DE=0001-01-01T00:00:00") + OffsetPresentation;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// File management functions.
//

// Adds the trailing separator to the passed directory path if it is missing.
//
// Parameters:
//  DirectoryPath - String - a directory path.
//  Platform - PlatformType - deprecated parameter.
//
// Returns:
//  String - the path to the directory, including the trailing separator.
//
// Example:
//  Result = AddFinalPathSeparator("C:\My directory"); // Returns "C:\My directory\".
//  Result = AddFinalPathSeparator("C:\My directory\"); // Returns "C:\My directory\".
//  Result = AddFinalPathSeparator("%APPDATA%"); // Returns "%APPDATA%\".
//
Function AddLastPathSeparator(Val DirectoryPath, Val Platform = Undefined) Export
	If IsBlankString(DirectoryPath) Then
		Return DirectoryPath;
	EndIf;
	
	CharToAdd = GetPathSeparator();
	
	If StrEndsWith(DirectoryPath, CharToAdd) Then
		Return DirectoryPath;
	Else 
		Return DirectoryPath + CharToAdd;
	EndIf;
EndFunction

// Generates the full path to a file from the directory path and the file name.
//
// Parameters:
//  DirectoryName - String - the path to the directory that contains the file.
//  FileName - String - the file name.
//
// Returns:
//   String - the full path to the file.
//
Function GetFullFileName(Val DirectoryName, Val FileName) Export

	If NOT IsBlankString(FileName) Then
		
		Slash = "";
		If (Right(DirectoryName, 1) <> "\") AND (Right(DirectoryName, 1) <> "/") Then
			Slash = ?(StrFind(DirectoryName, "\") = 0, "/", "\");
		EndIf;
		
		Return DirectoryName + Slash + FileName;
		
	Else
		
		Return DirectoryName;
		
	EndIf;

EndFunction

// Splits a full file path into parts.
//
// Parameters:
//  FullFileName - String - the full path to a file.
//  IsFolder - Boolean - the path-to-folder flag.
//
// Returns:
//   Structure - the file path split into parts similar to the File object properties.
//		FullName - the full path to the file. The same as the FullFileName input parameter.
//		Path - the path to the file directory.
//		Name - the file name, including the extension.
//		Extension - the file extension.
//		BaseName - the file name without the extension.
//			For example, if FullFileName = "c:	emp	est.txt", the following structure is generated:
//				FullName: "c:	emp	est.txt"
//				Path: "c:	emp\"
//				Name: "test.txt"
//				Extension: ".txt"
//				BaseName: "test"
//
Function ParseFullFileName(Val FullFileName, IsFolder = False) Export
	
	FileNameStructure = New Structure("FullName,Path,Name,Extension,BaseName");
	
	// Removes the end slash from the full file path and writes the resulted full path to the structure.
	If IsFolder AND (Right(FullFileName, 1) = "/" Or Right(FullFileName, 1) = "\") Then
		If IsFolder Then
			FullFileName = Mid(FullFileName, 1, StrLen(FullFileName) - 1);
		Else
			// If the file path ends with a slash, the file has no name.
			FileNameStructure.Insert("FullName", FullFileName); 
			FileNameStructure.Insert("Path", FullFileName); 
			FileNameStructure.Insert("Name", ""); 
			FileNameStructure.Insert("Extension", ""); 
			FileNameStructure.Insert("BaseName", ""); 
			Return FileNameStructure;
		EndIf;
	EndIf;
	FileNameStructure.Insert("FullName", FullFileName); 
	
	// If the full file path is blank, other structure return parameters are blank.
	If StrLen(FullFileName) = 0 Then 
		FileNameStructure.Insert("Path", ""); 
		FileNameStructure.Insert("Name", ""); 
		FileNameStructure.Insert("Extension", ""); 
		FileNameStructure.Insert("BaseName", ""); 
		Return FileNameStructure;
	EndIf;
	
	// Extracts the file path and the file name.
	If StrFind(FullFileName, "/") > 0 Then
		SeparatorPosition = StrFind(FullFileName, "/", SearchDirection.FromEnd);
	ElsIf StrFind(FullFileName, "\") > 0 Then
		SeparatorPosition = StrFind(FullFileName, "\", SearchDirection.FromEnd);
	Else
		SeparatorPosition = 0;
	EndIf;
	FileNameStructure.Insert("Path", Left(FullFileName, SeparatorPosition)); 
	FileNameStructure.Insert("Name", Mid(FullFileName, SeparatorPosition + 1));
	
	// Extracts the file extension (folders have no extensions).
	If IsFolder Then
		FileNameStructure.Insert("Extension", "");
		FileNameStructure.Insert("BaseName", FileNameStructure.Name);
	Else
		PointPosition = StrFind(FileNameStructure.Name, ".", SearchDirection.FromEnd);
		If PointPosition = 0 Then
			FileNameStructure.Insert("Extension", "");
			FileNameStructure.Insert("BaseName", FileNameStructure.Name);
		Else
			FileNameStructure.Insert("Extension", Mid(FileNameStructure.Name, PointPosition));
			FileNameStructure.Insert("BaseName", Left(FileNameStructure.Name, PointPosition - 1));
		EndIf;
	EndIf;
	
	Return FileNameStructure;
	
EndFunction

// Splits the URI string and returns it as a structure.
// The following normalizations are described based on RFC 3986.
//
// Parameters:
//  URIString - String - link to the resource in the following format:
//                       <schema>://<username>:<password>@<domain>:<port>/<path>?<query_string>#<fragment_id.
//
// Returns:
//  Structure - composite parts of the URI according to the format:
//   * Schema - String - the URI schema.
//   * Username         - String - the username from the URI.
//   * Password - String - the URI password.
//   * ServerName - String - the <host>:<port> URI part.
//   * Host - String - the URI host.
//   * Port - String - the URI port.
//   * PathAtServer - String - the <path>?<parameters>#<anchor> URI part.
//
Function URIStructure(Val URIString) Export
	
	URIString = TrimAll(URIString);
	
	// Schema
	Schema = "";
	Position = StrFind(URIString, "://");
	If Position > 0 Then
		Schema = Lower(Left(URIString, Position - 1));
		URIString = Mid(URIString, Position + 3);
	EndIf;
	
	// Connection string and path on the server.
	ConnectionString = URIString;
	PathAtServer = "";
	Position = StrFind(ConnectionString, "/");
	If Position > 0 Then
		PathAtServer = Mid(ConnectionString, Position + 1);
		ConnectionString = Left(ConnectionString, Position - 1);
	EndIf;
	
	// User details and server name.
	AuthorizationString = "";
	ServerName = ConnectionString;
	Position = StrFind(ConnectionString, "@");
	If Position > 0 Then
		AuthorizationString = Left(ConnectionString, Position - 1);
		ServerName = Mid(ConnectionString, Position + 1);
	EndIf;
	
	// Username and password.
	Username = AuthorizationString;
	Password = "";
	Position = StrFind(AuthorizationString, ":");
	If Position > 0 Then
		Username = Left(AuthorizationString, Position - 1);
		Password = Mid(AuthorizationString, Position + 1);
	EndIf;
	
	// The host and port.
	Host = ServerName;
	Port = "";
	Position = StrFind(ServerName, ":");
	If Position > 0 Then
		Host = Left(ServerName, Position - 1);
		Port = Mid(ServerName, Position + 1);
		If Not StringFunctionsClientServer.OnlyNumbersInString(Port) Then
			Port = "";
		EndIf;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Schema", Schema);
	Result.Insert("Username", Username);
	Result.Insert("Password", Password);
	Result.Insert("ServerName", ServerName);
	Result.Insert("Host", Host);
	Result.Insert("Port", ?(IsBlankString(Port), Undefined, Number(Port)));
	Result.Insert("PathAtServer", PathAtServer);
	
	Return Result;
	
EndFunction

// Parses the string into an array, using dot (.), slash mark (/), and backslash (\) as separators.
//
// Parameters:
//  String - String - the source string.
//
// Returns:
//  Array - a collection of string fragments.
//
Function ParseStringByDotsAndSlashes(Val String) Export
	
	Var CurrentPosition;
	
	Fragments = New Array;
	
	StartPosition = 1;
	
	For CurrentPosition = 1 To StrLen(String) Do
		CurrentChar = Mid(String, CurrentPosition, 1);
		If CurrentChar = "." Or CurrentChar = "/" Or CurrentChar = "\" Then
			CurrentFragment = Mid(String, StartPosition, CurrentPosition - StartPosition);
			StartPosition = CurrentPosition + 1;
			Fragments.Add(CurrentFragment);
		EndIf;
	EndDo;
	
	If StartPosition <> CurrentPosition Then
		CurrentFragment = Mid(String, StartPosition, CurrentPosition - StartPosition);
		Fragments.Add(CurrentFragment);
	EndIf;
	
	Return Fragments;
	
EndFunction

// Returns the file extension.
//
// Parameters:
//  FileName - String - the file name (with or without the directory).
//
// Returns:
//   String - the file extension.
//
Function GetFileNameExtension(Val FileName) Export
	
	Extension = "";
	
	CharPosition = StrLen(FileName);
	While CharPosition >= 1 Do
		
		If Mid(FileName, CharPosition, 1) = "." Then
			
			Extension = Mid(FileName, CharPosition + 1);
			Break;
		EndIf;
		
		CharPosition = CharPosition - 1;
	EndDo;

	Return Extension;
	
EndFunction

// Converts the file extension to lower case (without the dot).
//
// Parameters:
//  Extension - String - the file extension.
//
// Returns:
//  String - the converted extension.
//
Function ExtensionWithoutPoint(Val Extension) Export
	
	Extension = Lower(TrimAll(Extension));
	
	If Mid(Extension, 1, 1) = "." Then
		Extension = Mid(Extension, 2);
	EndIf;
	
	Return Extension;
	
EndFunction

// Returns the file name with extension.
// If the extension is blank, the dot (.) is not added.
//
// Parameters:
//  BaseName - String - the file name without extension.
//  Extension - String - the file extension.
//
// Returns:
//  String - the file name with extension.
//
Function GetNameWithExtension(NameWithoutExtension, Extension) Export
	
	NameWithExtension = NameWithoutExtension;
	
	If Extension <> "" Then
		NameWithExtension = NameWithExtension + "." + Extension;
	EndIf;
	
	Return NameWithExtension;
	
EndFunction

// Returns a string of illegal file name characters.
// See the list of symbols on https://en.wikipedia.org/wiki/Filename#Reserved_characters_and_words.
// Returns:
//   String - the illegal file name characters.
Function GetProhibitedCharsInFileName() Export

	DisallowedCharacters = """/\[]:;|=?*<>";
	DisallowedCharacters = DisallowedCharacters + Chars.Tab;
	Return DisallowedCharacters;

EndFunction

// Checks whether the file name contains illegal characters.
//
// Parameters:
//  FileName - String - a file name.
//
// Returns:
//   Array - an array of illegal symbols found in the file name.
//              If no illegal characters are found, returns an empty array.
Function FindProhibitedCharsInFileName(FileName) Export

	DisallowedCharacters = GetProhibitedCharsInFileName();
	
	FoundProhibitedCharsArray = New Array;
	
	For CharPosition = 1 To StrLen(DisallowedCharacters) Do
		CharToCheck = Mid(DisallowedCharacters,CharPosition,1);
		If StrFind(FileName,CharToCheck) <> 0 Then
			FoundProhibitedCharsArray.Add(CharToCheck);
		EndIf;
	EndDo;
	
	Return FoundProhibitedCharsArray;

EndFunction

// Replaces illegal characters in a file name to legal characters.
//
// Parameters:
//  FileName - String - an input file name.
//  ReplaceWith - String - the string to substitute an illegal character.
//
// Returns:
//   String - the modified file name.
//
Function ReplaceProhibitedCharsInFileName(Val FileName, ReplaceWith = " ") Export

	Result = FileName;
	FoundProhibitedCharsArray = FindProhibitedCharsInFileName(Result);
	For Each ProhibitedChar In FoundProhibitedCharsArray Do
		Result = StrReplace(Result, ProhibitedChar, ReplaceWith);
	EndDo;
	
	Return Result;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Email address management functions.
//

// Parses through a string of email addresses. Validates the addresses.
//
// Parameters:
//  AddressList - String - email addresses separated by commas or semicolons. For example:
//                           Recipient1 <Address1>, Recipient2 <Address2>... RecipientN <AddressN>.
//
// Returns:
//  Array - an array of email address structures.
//           The structure includes the following fields:
//             Alias - String - the recipient name presentation.
//             Address - String - a valid emal address.
//                                       If an email-like text found, but it does not meet the 
//                                       requirements, the text is interpreted as an Alias field value.
//             ErrorDescription - String - a text presentation of the error. If no errors are found, it is a blank string.
//
Function EmailsFromString(Val AddressesList) Export
	
	Result = New Array;
	
	// Replacing brackets with space characters.
	BracketChars = "<>()[]";
	Row = ReplaceCharsInStringWithSpaces(AddressesList, BracketChars);
	
	// Replacing comma delimiters to semicolons.
	Row = StrReplace(Row, ",", ";");
	
	// Parsing the mailbox-list into mailboxes.
	AddressesArray = StrSplit(Row, ";", False);
	
	// Extracting the alias (display-name) and the address (addr-spec) from the address string (mailbox).
	For Each AddressString In AddressesArray Do
		If IsBlankString(AddressString) Then
			Continue;
		EndIf;
		
		Alias = "";
		Address = "";
		ErrorDescription = "";
		
		If StrOccurrenceCount(AddressString, "@") <> 1 Then
			Alias = AddressString;
		Else
			// Everything that does not a valid email address is interpreted as an alias.
			For Each Substring In StrSplit(AddressString, " ", False) Do
				If IsBlankString(Address) AND EmailAddressMeetsRequirements(Substring) Then
					Address = Substring;
				Else
					Alias = Alias + " " + Substring;
				EndIf;
			EndDo;
		EndIf;
		
		Alias = TrimAll(Alias);
		
		// Validation
		AddressDefined = Not IsBlankString(Address);
		StringContainsEmail = StrFind(AddressString, "@") > 0;
		
		If Not AddressDefined Then 
			If StringContainsEmail Then 
				ErrorDescription = NStr("ru = 'Адрес электронной почты содержит ошибки'; en = 'The email address contains errors.'; pl = 'Adres e-mail zawiera błędy';es_ES = 'Dirección de correo electrónico contiene errores';es_CO = 'Dirección de correo electrónico contiene errores';tr = 'E-posta adresi hata içeriyor.';it = 'L''indirizzo email contiene errori.';de = 'Die E-Mail-Adresse enthält Fehler'");
			Else
				ErrorDescription = NStr("ru = 'Строка не содержит адреса электронной почты'; en = 'The string does not contain an email address.'; pl = 'Wers nie zawiera adresu e-mail';es_ES = 'La línea no contiene una dirección de correo electrónico';es_CO = 'La línea no contiene una dirección de correo electrónico';tr = 'Dize e-posta adresi içermiyor.';it = 'La stringa non contiene un indirizzo email.';de = 'Die Zeichenfolge enthält keine E-Mail-Adresse'");
			EndIf;
		EndIf;
		
		AddressStructure = New Structure("Alias,Address,ErrorDescription", Alias, Address, ErrorDescription);
		Result.Add(AddressStructure);
	EndDo;
	
	Return Result;
	
EndFunction

// Checks whether the email address meets the RFC 5321, RFC 5322, RFC 5335, RFC 5336, and RFC 5336 
// requirements.
// Also, restricts the usage of special symbols.
// 
// Parameters:
//  Address - String - an email to check.
//  AllowLocalAddresses - Boolean - do not raise an error if the email address is missing a domain.
//
// Returns:
//  Boolean - True, if no errors occurred.
//
Function EmailAddressMeetsRequirements(Val Address, AllowLocalAddresses = False) Export
	
	// Symbols that are allowed in email addresses.
	Letters = "abcdefghijklmnopqrstuvwxyz";
	Numbers = "0123456789";
	SpecialChars = ".@_-:+";
	
	// Checking the at sing (@)
	If StrOccurrenceCount(Address, "@") <> 1 Then
		Return False;
	EndIf;
	
	// Allowing only one column.
	If StrOccurrenceCount(Address, ":") > 1 Then
		Return False;
	EndIf;
	
	// Checking for double dots.
	If StrFind(Address, "..") > 0 Then
		Return False;
	EndIf;
	
	// Adjusting the address to the lower case.
	Address = Lower(Address);
	
	// Checking for illegal symbols.
	If Not StringContainsAllowedCharsOnly(Address, Letters + Numbers + SpecialChars) Then
		Return False;
	EndIf;
	
	// Splitting the address into a local part and domain.
	Position = StrFind(Address,"@");
	LocalName = Left(Address, Position - 1);
	Domain = Mid(Address, Position + 1);
	
	// Checking whether LocalName and Domain are filled and meet the length requirements.
	If IsBlankString(LocalName)
	 	Or IsBlankString(Domain)
		Or StrLen(LocalName) > 64
		Or StrLen(Domain) > 255 Then
		
		Return False;
	EndIf;
	
	// Checking whether there are any special characters at the beginning and at the end of LocalName and Domain.
	If HasCharsLeftRight(Domain, SpecialChars) Then
		Return False;
	EndIf;
	
	// A domain must contain at least one dot.
	If Not AllowLocalAddresses AND StrFind(Domain,".") = 0 Then
		Return False;
	EndIf;
	
	// A domain must not contain underscores (_).
	If StrFind(Domain,"_") > 0 Then
		Return False;
	EndIf;
	
	// A domain must not contain colons (:).
	If StrFind(Domain,":") > 0 Then
		Return False;
	EndIf;
	
	// A domain must not contain plus signs.
	If StrFind(Domain,"+") > 0 Then
		Return False;
	EndIf;
	
	// Extracting a top-level domain (TLD) from the domain name.
	Zone = Domain;
	Position = StrFind(Zone,".");
	While Position > 0 Do
		Zone = Mid(Zone, Position + 1);
		Position = StrFind(Zone,".");
	EndDo;
	
	// Checking TLD (at least two characters, letters only).
	Return AllowLocalAddresses Or StrLen(Zone) >= 2 AND StringContainsAllowedCharsOnly(Zone,Letters);
	
EndFunction

// Validates a string of email addresses.
//
//  String format:
//  Z = UserName|[User Name] [<]user@email_server[>], Sting = Z[<delimiter*>Z].
// 
//   * Delimiter - any delimiting character.
//
// Parameters:
//  EmailAddressString - String - a valid email address string.
//  RaiseException - Boolean - if False and the parsing fails, no exception is raised.
//
// Returns:
//  Structure - the parsing result.
//   * Status - Boolean - the validation result: successful or failed.
//   * Value - Array - a collection with the following structure (available if Status is True):
//    ** Address - String - the recipient email.
//    ** Presentation - String - the recipient name.
//   * ErrorMessage - String - the error details (available if Status is False).
//
//  NOTE. The function returns an array of structures, where one field can be empty.
//          Subsystems can call the function to map user names to email addresses.
//         
//          Therefore, before sending an email, ensure that the email address field is not empty.
//         
//
Function ParseStringWithEmailAddresses(Val EmailAddressString, RaiseException = True) Export
	
	Result = New Array;
	
	DisallowedCharacters = "!#$%^&*()`~|\/=";
	
	ProhibitedCharsMessage = NStr("ru = 'Недопустимый символ ""%1"" в адресе электронной почты ""%2""'; en = 'Prohibited character %1 in the email address %2.'; pl = 'Nieprawidłowy znak ""%1"" w adresie e-mail ""%2""';es_ES = 'Símbolo inválido ""%1"" en la dirección de correo electrónico ""%2""';es_CO = 'Símbolo inválido ""%1"" en la dirección de correo electrónico ""%2""';tr = 'E-posta adresinde geçersiz ""%1"" karakter ""%2""';it = 'Carattere proibito %1 nell''indirizzo email %2.';de = 'Ungültiges Zeichen ""%1"" in E-Mail-Adresse ""%2""'");
	InvalidEmailFormatMessage = NStr("ru = 'Некорректный адрес электронной почты ""%1""'; en = 'Invalid email address: %1.'; pl = 'Niepoprawny adres e-mail ""%1""';es_ES = 'Dirección de correo electrónico incorrecta ""%1""';es_CO = 'Dirección de correo electrónico incorrecta ""%1""';tr = 'Geçersiz e-posta adresi: %1.';it = 'Indirizzo email non valido: %1.';de = 'Falsche E-Mail-Adresse ""%1""'");
	
	EmailAddressString = StrReplace(EmailAddressString, ",", ";");
	SubstringArrayToProcess = StrSplit(TrimAll(EmailAddressString), ";", False);
	
	For Each AddressString In SubstringArrayToProcess Do
		
		Index = 1;               // Number of the character to process.
		Accumulator = "";          // Character accumulator. After the end of analysis, it passes its value to the full name or to the 
		// mail address.
		RecipientFullName = "";   // Variable that accumulates the addressee name.
		EmailAddress = "";       // The variable that accumulates the email address.
		// 1. Generating the full name. Takes any recipient name legal characters.
		// 2. Generating the email address. Takes any email address legal characters.
		// 3. Email address finalization. Takes delimiters or space signs.
		ParsingStage = 1; 
		
		While Index <= StrLen(AddressString) Do
			
			Char = Mid(AddressString, Index, 1);
			
			If      Char = " " Then
				Index = ? ((SkipSpaces(AddressString, Index, " ") - 1) > Index,
				SkipSpaces(AddressString, Index, " ") - 1,
				Index);
				If      ParsingStage = 1 Then
					RecipientFullName = RecipientFullName + Accumulator + " ";
				ElsIf ParsingStage = 2 Then
					EmailAddress = Accumulator;
					ParsingStage = 3;
				EndIf;
				Accumulator = "";
			ElsIf Char = "@" Then
				If      ParsingStage = 1 Then
					ParsingStage = 2;
					
					For PCSearchIndex = 1 To StrLen(Accumulator) Do
						If StrFind(DisallowedCharacters, Mid(Accumulator, PCSearchIndex, 1)) > 0 AND RaiseException Then
							Raise StringFunctionsClientServer.SubstituteParametersToString(ProhibitedCharsMessage,
								Mid(Accumulator, PCSearchIndex, 1),AddressString);
						EndIf;
					EndDo;
					
					Accumulator = Accumulator + Char;
				ElsIf ParsingStage = 2 AND RaiseException Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(InvalidEmailFormatMessage,AddressString);
				ElsIf ParsingStage = 3 AND RaiseException Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(InvalidEmailFormatMessage,AddressString);
				EndIf;
			Else
				If ParsingStage = 2 OR ParsingStage = 3 Then
					If StrFind(DisallowedCharacters, Char) > 0 AND RaiseException Then
						Raise StringFunctionsClientServer.SubstituteParametersToString(ProhibitedCharsMessage,Char,AddressString);
					EndIf;
				EndIf;
				
				Accumulator = Accumulator + Char;
			EndIf;
			
			Index = Index + 1;
		EndDo;
		
		If      ParsingStage = 1 Then
			RecipientFullName = RecipientFullName + Accumulator;
		ElsIf ParsingStage = 2 Then
			EmailAddress = Accumulator;
		EndIf;
		
		If IsBlankString(EmailAddress) AND (Not IsBlankString(RecipientFullName)) AND RaiseException Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(InvalidEmailFormatMessage, RecipientFullName);
		ElsIf StrOccurrenceCount(EmailAddress, "@") <> 1 AND RaiseException Then 
			Raise StringFunctionsClientServer.SubstituteParametersToString(InvalidEmailFormatMessage,EmailAddress);
		EndIf;
		
		If NOT (IsBlankString(RecipientFullName) AND IsBlankString(EmailAddress)) Then
			Result.Add(CheckAndPrepareEmailAddress(RecipientFullName, EmailAddress));
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Dynamic list filter and parameter management functions.
//

// Searches for the item and the group of the dynamic list filter by the passed field name or presentation.
//
// Parameters:
//  SearchArea - DataCompositionFilter, DataCompositionFilterItemCollection,
//                  DataCompositionFilterItemGroup - a container of items and filter groups. For 
//                  example, List.Filter or a group in a filer.
//  FieldName - String - a composition field name. Not applicable to groups.
//  Presentation - String - the composition field presentation.
//
// Returns:
//  Array - a collection of filters.
//
Function FindFilterItemsAndGroups(Val SearchArea,
									Val FieldName = Undefined,
									Val Presentation = Undefined) Export
	
	If ValueIsFilled(FieldName) Then
		SearchValue = New DataCompositionField(FieldName);
		SearchMethod = 1;
	Else
		SearchMethod = 2;
		SearchValue = Presentation;
	EndIf;
	
	ItemArray = New Array;
	
	FindRecursively(SearchArea.Items, ItemArray, SearchMethod, SearchValue);
	
	Return ItemArray;
	
EndFunction

// Adds filter groups to ItemCollection.
//
// Parameters:
//  ItemCollection - DataCompositionFilter, DataCompositionFilterItemCollection,
//                       DataCompositionFilterItemGroup - a container of items and filter groups. 
//                       For example, List.Filter or a group in a filer.
//  Presentation - String - the group presentation.
//  GroupType - DataCompositionFilterItemsGroupType - the group type.
//
// Returns:
//  DataCompositionFilterItemGroup - a filter group.
//
Function CreateFilterItemGroup(Val ItemCollection, Presentation, GroupType) Export
	
	If TypeOf(ItemCollection) = Type("DataCompositionFilterItemGroup") Then
		ItemCollection = ItemCollection.Items;
	EndIf;
	
	FilterItemsGroup = FindFilterItemByPresentation(ItemCollection, Presentation);
	If FilterItemsGroup = Undefined Then
		FilterItemsGroup = ItemCollection.Add(Type("DataCompositionFilterItemGroup"));
	Else
		FilterItemsGroup.Items.Clear();
	EndIf;
	
	FilterItemsGroup.Presentation    = Presentation;
	FilterItemsGroup.Application       = DataCompositionFilterApplicationType.Items;
	FilterItemsGroup.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	FilterItemsGroup.GroupType        = GroupType;
	FilterItemsGroup.Use    = True;
	
	Return FilterItemsGroup;
	
EndFunction

// Adds a composition item into a composition item container.
//
// Parameters:
//  AreaToAddTo - DataCompositionFilterItemCollection - a container with items and filter groups. 
//                                                                 For example, List.Filter or a group in a filter.
//  FieldName - String - a data composition field name. Required.
//  RightValue - Arbitrary - the value to compare to.
//  ComparisonType            - DataCompositionComparisonType - a comparison type.
//  Presentation           - String - presentation of the data composition item.
//  Usage - Boolean - the flag that indicates whether the item is used.
//  DisplayMode - DataCompositionSettingItemDisplayMode - the item display mode.
//  UserSettingID - String - see DataCompositionFilter.UserSettingID in Syntax Assistant. 
//                                                    
// Returns:
//  DataCompositionFilterItem - a composition item.
//
Function AddCompositionItem(AreaToAddTo,
									Val FieldName,
									Val ComparisonType,
									Val RightValue = Undefined,
									Val Presentation  = Undefined,
									Val Usage  = Undefined,
									val DisplayMode = Undefined,
									val UserSettingID = Undefined) Export
	
	Item = AreaToAddTo.Items.Add(Type("DataCompositionFilterItem"));
	Item.LeftValue = New DataCompositionField(FieldName);
	Item.ComparisonType = ComparisonType;
	
	If DisplayMode = Undefined Then
		Item.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	Else
		Item.ViewMode = DisplayMode;
	EndIf;
	
	If RightValue <> Undefined Then
		Item.RightValue = RightValue;
	EndIf;
	
	If Presentation <> Undefined Then
		Item.Presentation = Presentation;
	EndIf;
	
	If Usage <> Undefined Then
		Item.Use = Usage;
	EndIf;
	
	// Important: The ID must be set up in the final stage of the item customization or it will be 
	// copied to the user settings in a half-filled condition.
	// 
	If UserSettingID <> Undefined Then
		Item.UserSettingID = UserSettingID;
	ElsIf Item.ViewMode <> DataCompositionSettingsItemViewMode.Inaccessible Then
		Item.UserSettingID = FieldName;
	EndIf;
	
	Return Item;
	
EndFunction

// Changes the filter item with the specified field name or presentation.
//
// Parameters:
//  SearchArea - DataCompositionFilterItemCollection - a container with items and filter groups, for 
//                                                             example, List.Filter or a group in the filter.
//  FieldName - String - a data composition field name. Required.
//  Presentation           - String - presentation of the data composition item.
//  RightValue - Arbitrary - the value to compare to.
//  ComparisonType            - DataCompositionComparisonType - a comparison type.
//  Usage - Boolean - the flag that indicates whether the item is used.
//  DisplayMode - DataCompositionSettingItemDisplayMode - the item display mode.
//  UserSettingID - String - see DataCompositionFilter.UserSettingID in Syntax Assistant. 
//                                                    
//
// Returns:
//  Number - the changed item count.
//
Function ChangeFilterItems(SearchArea,
								Val FieldName = Undefined,
								Val Presentation = Undefined,
								Val RightValue = Undefined,
								Val ComparisonType = Undefined,
								Val Usage = Undefined,
								Val DisplayMode = Undefined,
								Val UserSettingID = Undefined) Export
	
	If ValueIsFilled(FieldName) Then
		SearchValue = New DataCompositionField(FieldName);
		SearchMethod = 1;
	Else
		SearchMethod = 2;
		SearchValue = Presentation;
	EndIf;
	
	ItemArray = New Array;
	
	FindRecursively(SearchArea.Items, ItemArray, SearchMethod, SearchValue);
	
	For Each Item In ItemArray Do
		If FieldName <> Undefined Then
			Item.LeftValue = New DataCompositionField(FieldName);
		EndIf;
		If Presentation <> Undefined Then
			Item.Presentation = Presentation;
		EndIf;
		If Usage <> Undefined Then
			Item.Use = Usage;
		EndIf;
		If ComparisonType <> Undefined Then
			Item.ComparisonType = ComparisonType;
		EndIf;
		If RightValue <> Undefined Then
			Item.RightValue = RightValue;
		EndIf;
		If DisplayMode <> Undefined Then
			Item.ViewMode = DisplayMode;
		EndIf;
		If UserSettingID <> Undefined Then
			Item.UserSettingID = UserSettingID;
		EndIf;
	EndDo;
	
	Return ItemArray.Count();
	
EndFunction

// Delete filter items that contain the given field name or presentation.
//
// Parameters:
//  AreaToDelete - DataCompositionFilterItemCollection - a container of items or filter groups. For 
//                                                               example, List.Filter or a group in the filter.
//  FieldName - String - the composition field name. Not applicable to groups.
//  Presentation   - String - the composition field presentation.
//
Procedure DeleteFilterItems(Val AreaToDelete, Val FieldName = Undefined, Val Presentation = Undefined) Export
	
	If ValueIsFilled(FieldName) Then
		SearchValue = New DataCompositionField(FieldName);
		SearchMethod = 1;
	Else
		SearchMethod = 2;
		SearchValue = Presentation;
	EndIf;
	
	ItemArray = New Array;
	
	FindRecursively(AreaToDelete.Items, ItemArray, SearchMethod, SearchValue);
	
	For Each Item In ItemArray Do
		If Item.Parent = Undefined Then
			AreaToDelete.Items.Delete(Item);
		Else
			Item.Parent.Items.Delete(Item);
		EndIf;
	EndDo;
	
EndProcedure

// Adds or replaces the existing filter item.
//
// Parameters:
//  WhereToAdd - DataCompositionFilterItemCollection - a container with items and filter groups, for 
//                                     example, List.Filter or a group in the filter.
//  FieldName - String - a data composition field name. Required.
//  RightValue - Arbitrary - the value to compare to.
//  ComparisonType            - DataCompositionComparisonType - a comparison type.
//  Presentation           - String - presentation of the data composition item.
//  Usage - Boolean - the flag that indicates whether the item is used.
//  DisplayMode - DataCompositionSettingItemDisplayMode - the item display mode.
//  UserSettingID - String - see DataCompositionFilter.UserSettingID in Syntax Assistant. 
//                                                    
//
Procedure SetFilterItem(WhereToAdd,
								Val FieldName,
								Val RightValue = Undefined,
								Val ComparisonType = Undefined,
								Val Presentation = Undefined,
								Val Usage = Undefined,
								Val DisplayMode = Undefined,
								Val UserSettingID = Undefined) Export
	
	ModifiedCount = ChangeFilterItems(WhereToAdd, FieldName, Presentation,
							RightValue, ComparisonType, Usage, DisplayMode, UserSettingID);
	
	If ModifiedCount = 0 Then
		If ComparisonType = Undefined Then
			If TypeOf(RightValue) = Type("Array")
				Or TypeOf(RightValue) = Type("FixedArray")
				Or TypeOf(RightValue) = Type("ValueList") Then
				ComparisonType = DataCompositionComparisonType.InList;
			Else
				ComparisonType = DataCompositionComparisonType.Equal;
			EndIf;
		EndIf;
		If DisplayMode = Undefined Then
			DisplayMode = DataCompositionSettingsItemViewMode.Inaccessible;
		EndIf;
		AddCompositionItem(WhereToAdd, FieldName, ComparisonType,
								RightValue, Presentation, Usage, DisplayMode, UserSettingID);
	EndIf;
	
EndProcedure

// Adds or replaces a filter item of a dynamic list.
//
// Parameters:
//   DynamicList - DynamicList - the list to be filtered.
//   FieldName - String - the field the filter to apply to.
//   RightValue - Arbitrary - the filter value.
//       Optional. The default value is Undefined.
//       Warning! If Undefined is passed, the value will not be changed.
//   ComparisonType  - DataCompositionComparisonType - a filter condition.
//   Presentation - String - presentation of the data composition item.
//       Optional. The default value is Undefined.
//       If another value is specified, only the presentation flag is shown, not the value.
//       To show the value, pass an empty string.
//   Usage - Boolean - the flag that indicates whether to apply the filter.
//       Optional. The default value is Undefined.
//   DisplayMode - DataCompositionSettingItemDisplayMode - the filter display mode.
//                                                                          
//       * DataCompositionSettingItemDisplayMode.QuickAccess - in the Quick Settings bar on top of the list.
//       * DataCompositionSettingItemDisplayMode.Normal - in the list settings (submenu More).
//       * DataCompositionSettingItemDisplayMode.Inaccessible - privent users from changing the filter.
//   UserSettingID - String - the filter unique ID.
//       Used to link user settings.
//
Procedure SetDynamicListFilterItem(DynamicList, FieldName,
	RightValue = Undefined,
	ComparisonType = Undefined,
	Presentation = Undefined,
	Usage = Undefined,
	DisplayMode = Undefined,
	UserSettingID = Undefined) Export
	
	If DisplayMode = Undefined Then
		DisplayMode = DataCompositionSettingsItemViewMode.Inaccessible;
	EndIf;
	
	If DisplayMode = DataCompositionSettingsItemViewMode.Inaccessible Then
		DynamicListFilter = DynamicList.SettingsComposer.FixedSettings.Filter;
	Else
		DynamicListFilter = DynamicList.SettingsComposer.Settings.Filter;
	EndIf;
	
	SetFilterItem(
		DynamicListFilter,
		FieldName,
		RightValue,
		ComparisonType,
		Presentation,
		Usage,
		DisplayMode,
		UserSettingID);
	
EndProcedure

// Delete a filter group item of a dynamic list.
//
// Parameters:
//  DynamicList - DynamicList - the form attribute whose filter is to be modified.
//  FieldName - String - the composition field name. Not applicable to groups.
//  Presentation   - String - the composition field presentation.
//
Procedure DeleteDynamicListFilterGroupItems(DynamicList, FieldName = Undefined, Presentation = Undefined) Export
	
	DeleteFilterItems(
		DynamicList.SettingsComposer.FixedSettings.Filter,
		FieldName,
		Presentation);
	
	DeleteFilterItems(
		DynamicList.SettingsComposer.Settings.Filter,
		FieldName,
		Presentation);
	
EndProcedure

// Sets or modifies the ParameterName parameter of the List dynamic list.
//
// Parameters:
//  List          - DynamicList - the form attribute whose parameter is to be modified.
//  ParameterName    - String             - name of the dynamic list parameter.
//  Value        - Arbitrary        - new value of the parameter.
//  Usage   - Boolean             - flag indicating whether the parameter is used.
//
Procedure SetDynamicListParameter(List, ParameterName, Value, Usage = True) Export
	
	DataCompositionParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	If DataCompositionParameterValue <> Undefined Then
		If Usage AND DataCompositionParameterValue.Value <> Value Then
			DataCompositionParameterValue.Value = Value;
		EndIf;
		If DataCompositionParameterValue.Use <> Usage Then
			DataCompositionParameterValue.Use = Usage;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for working with managed forms.
//

// Gets the form attribute value.
//
// Parameters:
//  Form - ClientApplicationForm - a form.
//  AttributePath - String - the path to the form attribute data, for example: "Object.AccrualMonth".
//
// Returns:
//  Arbitraty - the form attribute.
//
Function GetFormAttributeByPath(Form, AttributePath) Export
	
	NamesArray = StrSplit(AttributePath, ".");
	
	Object        = Form;
	LastField = NamesArray[NamesArray.Count()-1];
	
	For Cnt = 0 To NamesArray.Count()-2 Do
		Object = Object[NamesArray[Cnt]]
	EndDo;
	
	Return Object[LastField];
	
EndFunction

// Sets the value to the form attribute.
// Parameters:
//  Form - ClientApplicationForm - form that owns the attribute.
//  AttributePath - String - the path to the data, for example: "Object.AccrualMonth".
//  Value - Arbitrary - a value to set.
//  UnfilledOnly - Boolean - skips filling values for attributes with already filled values.
//                                  
Procedure SetFormAttributeByPath(Form, AttributePath, Value, UnfilledOnly = False) Export
	
	NamesArray = StrSplit(AttributePath, ".");
	
	Object        = Form;
	LastField = NamesArray[NamesArray.Count()-1];
	
	For Cnt = 0 To NamesArray.Count()-2 Do
		Object = Object[NamesArray[Cnt]]
	EndDo;
	If NOT UnfilledOnly OR NOT ValueIsFilled(Object[LastField]) Then
		Object[LastField] = Value;
	EndIf;
	
EndProcedure

// Searches for a filter item in the collection by the specified presentation.
//
// Parameters:
//  ItemCollection - DataCompositionFilterItemCollection - container with filter groups and items, 
//                                                                  such as List.Filter.Filter items or group.
//  Presentation - String - group presentation.
// 
// Returns:
//  DataCompositionFilterItem - filter item.
//
Function FindFilterItemByPresentation(ItemCollection, Presentation) Export
	
	ReturnValue = Undefined;
	
	For each FilterItem In ItemCollection Do
		If FilterItem.Presentation = Presentation Then
			ReturnValue = FilterItem;
			Break;
		EndIf;
	EndDo;
	
	Return ReturnValue
	
EndFunction

// Sets the PropertyName property of the ItemName form item to Value.
// Is applied when the form item might be missed on the form because of insufficient user rights for 
// an object, an object attribute, or a command.
//
// Parameters:
//  FormItems - AllFormItems, FormItems - a collection of managed form items.
//  ItemName   - String       - the form item name.
//  PropertyName   - String       - the name of the form item property to be set.
//  Value      - Arbitrary - the new value of the item.
// 
Procedure SetFormItemProperty(FormItems, ItemName, PropertyName, Value) Export
	
	FormItem = FormItems.Find(ItemName);
	If FormItem <> Undefined AND FormItem[PropertyName] <> Value Then
		FormItem[PropertyName] = Value;
	EndIf;
	
EndProcedure 

// Returns the value of the PropertyName property of the ItemName form item.
// Is applied when the form item might be missed on the form because of insufficient user rights for 
// an object, an object attribute, or a command.
//
// Parameters:
//  FormItems - AllFormItems, FormItems - a collection of managed form items.
//  ItemName   - String       - the form item name.
//  PropertyName   - String       - the name of the form item property.
// 
// Returns:
//   Abritrary - value of the PropertyName property of the ItemName form item.
// 
Function FormItemPropertyValue(FormItems, ItemName, PropertyName) Export
	
	FormItem = FormItems.Find(ItemName);
	Return ?(FormItem <> Undefined, FormItem[PropertyName], Undefined);
	
EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Predefined data processing.
//

// Retrieves a reference to the predefined item by its full name.
// Only the following objects can contain predefined objects:
//   - Catalogs
//   - Charts of characteristic types
//   - Charts of accounts
//   - Charts of calculation types
// After changing the list of predefined items, it is recommended that you run
// the UpdateCachedValues() method to clear the cache for Cached modules in the current session.
//
// Parameters:
//   PredefinedItemFullName - String - full path to the predefined item including name.
//     The format is identical to the PredefinedValue() global context function.
//     Example:
//       "Catalog.ContactInformationKinds.UserEmail"
//       "ChartOfAccounts.SelfFinancing.Materials"
//       "ChartOfCalculationTypes.Accruals.SalaryPayments".
//
// Returns:
//   AnyRef - reference to the predefined item.
//   Undefined - if the predefined item exists in metadata but not in the infobase.
//
Function PredefinedItem(FullPredefinedItemName) Export
	
	// Using a standard function to get:
	//  - blank references
	//  - enumeration values
	//  - business process route points
	If ".EMPTYREF" = Upper(Right(FullPredefinedItemName, 13))
		Or "ENUM." = Upper(Left(FullPredefinedItemName, 13)) 
		Or "BUSINESSPROCESS." = Upper(Left(FullPredefinedItemName, 14)) Then
		
		Return PredefinedValue(FullPredefinedItemName);
	EndIf;
	
	// Parsing the full name of the predefined item.
	FullNameParts = StrSplit(FullPredefinedItemName, ".");
	If FullNameParts.Count() <> 3 Then 
		Raise PredefinedValueNotFoundErrorText(FullPredefinedItemName);
	EndIf;
	
	FullMetadataObjectName = Upper(FullNameParts[0] + "." + FullNameParts[1]);
	PredefinedItemName = FullNameParts[2];
	
	// Cache to be called is determined by context.
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	PredefinedValues = StandardSubsystemsCached.RefsByPredefinedItemsNames(FullMetadataObjectName);
#Else
	PredefinedValues = StandardSubsystemsClientCached.RefsByPredefinedItemsNames(FullMetadataObjectName);
#EndIf

	// In case of error in metadata name.
	If PredefinedValues = Undefined Then 
		Raise PredefinedValueNotFoundErrorText(FullPredefinedItemName);
	EndIf;

	// Getting result from cache.
	Result = PredefinedValues.Get(PredefinedItemName);
	
	// If the predefined item does not exist in metadata.
	If Result = Undefined Then 
		Raise PredefinedValueNotFoundErrorText(FullPredefinedItemName);
	EndIf;
	
	// If the predefined item exists in metadata but not in the infobase.
	If Result = Null Then 
		Return Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other functions
//

// Returns a parameter structure template for establishing an external connection.
// Parameters have to be filled with required values and be passed
// to the Common.EstablishExternalConnection() method.
//
// Returns:
//  Structure - a collection of parameters
//
Function ParametersStructureForExternalConnection() Export
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("InfobaseOperatingMode", 0);
	ParametersStructure.Insert("InfobaseDirectory", "");
	ParametersStructure.Insert("NameOf1CEnterpriseServer", "");
	ParametersStructure.Insert("NameOfInfobaseOn1CEnterpriseServer", "");
	ParametersStructure.Insert("OperatingSystemAuthentication", False);
	ParametersStructure.Insert("UserName", "");
	ParametersStructure.Insert("UserPassword", "");
	
	Return ParametersStructure;
EndFunction

// Extracts connection parameters from the infobase connection string and passes parameters to 
// structure for setting external connections.
//
// Parameters:
//  ConnectionString - String - an infobase connection string.
// 
// Returns:
//  Structure - see ParametersStructureForExternalConnection. 
//
Function GetConnectionParametersFromInfobaseConnectionString(Val ConnectionString) Export
	
	Result = ParametersStructureForExternalConnection();
	
	Parameters = StringFunctionsClientServer.ParametersFromString(ConnectionString);
	
	Parameters.Property("File", Result.InfobaseDirectory);
	Parameters.Property("Srvr", Result.NameOf1CEnterpriseServer);
	Parameters.Property("Ref",  Result.NameOfInfobaseOn1CEnterpriseServer);
	
	Result.InfobaseOperatingMode = ?(Parameters.Property("File"), 0, 1);
	
	Return Result;
EndFunction

// For File mode, returns the full name of the directory, where the infobase is located.
// If the application runs in client/server mode, an empty string is returned.
//
// Returns:
//  String - full name of the directory where the file infobase is stored.
//
Function FileInfobaseDirectory() Export
	
	ConnectionParameters = StringFunctionsClientServer.ParametersFromString(InfoBaseConnectionString());
	
	If ConnectionParameters.Property("File") Then
		Return ConnectionParameters.File;
	EndIf;
	
	Return "";
EndFunction

// Gets value tree row ID (GetID() method) for the specified tree row field value.
// 
// Is used to determine the cursor position in hierarchical lists.
//
// Parameters:
//  FieldName - String - name of the column in value tree used for searching.
//  RowID - Number - value tree row ID returned by search.
//  TreeItemCollection - TreeItemCollectionFormData - collection to search.
//  RowKey - Arbitrary - the sought field value.
//  StopSearch - Boolean - flag indicating whether the search is to be stopped.
// 
Procedure GetTreeRowIDByFieldValue(FieldName, RowID, TreeItemsCollection, RowKey, StopSearch) Export
	
	For Each TreeRow In TreeItemsCollection Do
		
		If StopSearch Then
			Return;
		EndIf;
		
		If TreeRow[FieldName] = RowKey Then
			
			RowID = TreeRow.GetID();
			
			StopSearch = True;
			
			Return;
			
		EndIf;
		
		ItemCollection = TreeRow.GetItems();
		
		If ItemCollection.Count() > 0 Then
			
			GetTreeRowIDByFieldValue(FieldName, RowID, ItemCollection, RowKey, StopSearch);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Replaces prohibited characters in the XML string with the specified characters.
//
// Parameters:
//   Text - String - the string where invalid characters need to be replaced.
//   ReplacementChar - String - the string to be used instead of the invalid character in XML string.
// 
// Returns:
//    String - string resulting from replacement of invalid characters in XML string.
//
Function ReplaceProhibitedXMLChars(Val Text, ReplacementChar = " ") Export
	
#If NOT WebClient Then
	StartPosition = 1;
	Position = FindDisallowedXMLCharacters(Text, StartPosition);
	While Position > 0 Do
		ProhibitedChar = Mid(Text, Position, 1);
		Text = StrReplace(Text, ProhibitedChar, ReplacementChar);
		StartPosition = Position + StrLen(ReplacementChar);
		If StartPosition > StrLen(Text) Then
			Break;
		EndIf;
		Position = FindDisallowedXMLCharacters(Text, StartPosition);
	EndDo;
	
	Return Text;
#Else
	// Character codes from 0 to 2^16-1 that the FindDisallowedXMLCharacters method considers as not 
	// allowed: 0-8, 11-12, 14-31, 55296-57343.
	Total = "";
	StringLength = StrLen(Text);
	
	For CharNumber = 1 To StringLength Do
		Char = Mid(Text, CharNumber, 1);
		CharCode = CharCode(Char);
		
		If CharCode < 9
		 Or CharCode > 10    AND CharCode < 13
		 Or CharCode > 13    AND CharCode < 32
		 Or CharCode > 55295 AND CharCode < 57344 Then
			
			Char = ReplacementChar;
		EndIf;
		Total = Total + Char;
	EndDo;
	
	Return Total;
#EndIf
	
EndFunction

// Deletes prohibited characters from the XML string.
//
// Parameters:
//  Text - String - the string where invalid characters need to be replaced.
// 
// Returns:
//  String - string resulting from replacement of invalid characters in XML string.
//
Function DeleteProhibitedXMLChars(Val Text) Export
	
	Return ReplaceProhibitedXMLChars(Text, "");
	
EndFunction

// Compares two schedules.
//
// Parameters:
//	Schedule1 - JobSchedule - the first schedule.
//  Schedule2 - JobSchedule - the second schedule.
//
// Returns:
//  Boolean - True if the schedules are identical.
//
Function SchedulesAreIdentical(Val Schedule1, Val Schedule2) Export
	
	Return String(Schedule1) = String(Schedule2);
	
EndFunction

// Returns the code of the default configuration language, for example, "en".
//
// Returns:
//  String - language code.
//
Function DefaultLanguageCode() Export
	#If NOT ThinClient AND NOT WebClient AND NOT MobileClient Then
		Return Metadata.DefaultLanguage.LanguageCode;
	#Else
		Return StandardSubsystemsClient.ClientParameter("DefaultLanguageCode");
	#EndIf
EndFunction

// Returns True if a client application is connected to the infobase through a web server.
// Returns False if the client OS is not Linux.
//
// Returns:
//  Boolean - True if the application is connected.
//
Function ClientConnectedOverWebServer() Export
	
#If Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	InfobaseConnectionString = StandardSubsystemsServer.ClientParametersAtServer().Get("InfobaseConnectionString");
	
	If InfobaseConnectionString = Undefined Then
		Return False; // No client application
	EndIf;
#Else
	InfobaseConnectionString = InfoBaseConnectionString();
#EndIf
	
	Return StrFind(Upper(InfobaseConnectionString), "WS=") = 1;
	
EndFunction

// Returns True if the client application is running on Windows.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsWindowsClient() Export
	
#If Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	IsWindowsClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsWindowsClient");
	
	If IsWindowsClient = Undefined Then
		Return False; // No client application
	EndIf;
#Else
	SystemInfo = New SystemInfo;
	
	IsWindowsClient = SystemInfo.PlatformType = PlatformType.Windows_x86
	             OR SystemInfo.PlatformType = PlatformType.Windows_x86_64;
#EndIf
	
	Return IsWindowsClient;
	
EndFunction

// Returns True if the client application runs on OS X.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsOSXClient() Export
	
#If Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	IsOSXClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsOSXClient");
	
	If IsOSXClient = Undefined Then
		Return False; // No client application
	EndIf;
#Else
	SystemInfo = New SystemInfo;
	
	IsOSXClient = SystemInfo.PlatformType = PlatformType.MacOS_x86
	             OR SystemInfo.PlatformType = PlatformType.MacOS_x86_64;
#EndIf
	
	Return IsOSXClient;
	
EndFunction

// Returns True if the client application is running on Linux.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsLinuxClient() Export
	
#If Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	IsLinuxClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsLinuxClient");
	
	If IsLinuxClient = Undefined Then
		Return False; // No client application
	EndIf;
#Else
	SystemInfo = New SystemInfo;
	
	IsLinuxClient = SystemInfo.PlatformType = PlatformType.Linux_x86
	             OR SystemInfo.PlatformType = PlatformType.Linux_x86_64;
#EndIf
	
	Return IsLinuxClient;
	
EndFunction

// Returns True if the client application is a web client.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsWebClient() Export
	
#If WebClient Then
	Return True;
#ElsIf Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	IsWebClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsWebClient");
	
	If IsWebClient = Undefined Then
		Return False; // No client application
	EndIf;
	
	Return IsWebClient;
#Else
	Return False;
#EndIf
	
EndFunction

// Returns True if this is the Mac OS web client.
//
// Returns:
//  Boolean - True if the session runs in web client under Mac OS.
//
Function IsMacOSWebClient() Export
	
#If WebClient Then
	Return CommonClientCached.IsMacOSWebClient();
#ElsIf Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	IsMacOSWebClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsMacOSWebClient");
	
	If IsMacOSWebClient = Undefined Then
		Return False; // No client application
	EndIf;
	
	Return IsMacOSWebClient;
#Else
	Return False;
#EndIf
	
EndFunction

// Returns True if the client application is a mobile client.
//
// Returns:
//  Boolean - False if no client application is available.
//
Function IsMobileClient() Export
	
#If MobileClient Then
	Return True;
#ElsIf Server Or ThickClientOrdinaryApplication Then
	SetPrivilegedMode(True);
	
	IsMobileClient = StandardSubsystemsServer.ClientParametersAtServer().Get("IsMobileClient");
	
	If IsMobileClient = Undefined Then
		Return False; // No client application
	EndIf;
	
	Return IsMobileClient;
#Else
	Return False;
#EndIf
	
EndFunction

// Returns the amount of RAM available to the client application.
//
// Returns:
//  Number - number of GB of RAM, with tenths-place accuracy.
//  Undefined - no client application is available, meaning CurrentRunMode() = Undefined.
//
Function RAMAvailableForClientApplication() Export
	
#If Server Or ThickClientOrdinaryApplication Or  ExternalConnection Then
	SetPrivilegedMode(True);
	AvailableMemorySize = SessionParameters.ClientParametersAtServer.Get("RAM");
#Else
	SystemInfo = New  SystemInfo;
	AvailableMemorySize = Round(SystemInfo.RAM / 1024,  1);
#EndIf
	
	Return AvailableMemorySize;
	
EndFunction

// Returns True if debug mode is enabled.
//
// Returns:
//  Boolean - True if debug mode is enabled.
Function DebugMode() Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	ApplicationStartupParameter = SessionParameters.ClientParametersAtServer.Get("LaunchParameter");
#Else
	ApplicationStartupParameter = LaunchParameter;
#EndIf
	
	Return StrFind(ApplicationStartupParameter, "DebugMode") > 0;
EndFunction

// Raises an exception with Message if Condition is not True.
// Is applied for script self-diagnostics.
//
// Parameters:
//   Condition                - Boolean - if not True, exception is raised.
//   CheckContext       - String - for example, name of the procedure or function to check.
//   Message              - String - the message text. If it is not specified, the exception is 
//                                     raised with the default message.
//
Procedure Validate(Val Condition, Val Message = "", Val CheckContext = "") Export
	
	If Condition <> True Then
		If IsBlankString(Message) Then
			ExceptionText = NStr("ru = 'Недопустимая операция'; en = 'Invalid operation.'; pl = 'Niepoprawna operacja';es_ES = 'Operación inválida';es_CO = 'Operación inválida';tr = 'Geçersiz işlem';it = 'Operazione non valida.';de = 'Invalid operation'"); // Assertion failed
		Else
			ExceptionText = Message;
		EndIf;
		If Not IsBlankString(CheckContext) Then
			ExceptionText = ExceptionText + " " + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'в %1'; en = 'Context: %1.'; pl = 'w %1';es_ES = 'en %1';es_CO = 'en %1';tr = '%1 ''de';it = 'Contesto: %1.';de = 'in %1'"), CheckContext);
		EndIf;
		Raise ExceptionText;
	EndIf;
	
EndProcedure

// Raises an exception if the ParameterName parameter value type of the ProcedureOrFunctionName 
// procedure or function does not match the excepted one.
// Is intended for validating types of parameters passed to the interface procedures and functions.
//
// Parameters:
//   ProcedureOrFunctionName - String             - name of the procedure or function that contains the parameter to check.
//   ParameterName           - String             - name of the parameter to check.
//   ParameterValue      - Arbitrary       - actual value of the parameter.
//   ExpectedTypes  - TypesDescription, Type, Array - type(s) of the parameter of procedure or function.
//   ExpectedPropertyTypes   - Structures          - if the expected type is a structure, this 
//                                                 parameter can be used to specify its properties.
//
Procedure CheckParameter(Val ProcedureOrFunctionName, Val ParameterName, Val ParameterValue, 
	Val ExpectedTypes, Val PropertiesTypesToExpect = Undefined) Export
	
	Context = "CommonClientServer.CheckParameter";
	Validate(TypeOf(ProcedureOrFunctionName) = Type("String"), 
		NStr("ru = 'Недопустимое значение параметра ProcedureOrFunctionName'; en = 'Invalid value of ProcedureOrFunctionName parameter.'; pl = 'Niedopuszczalna wartość parametrów ProcedureOrFunctionName';es_ES = 'Valor inválido del parámetro ProcedureOrFunctionName.';es_CO = 'Valor inválido del parámetro ProcedureOrFunctionName.';tr = 'ProcedureOrFunctionName parametresinin geçersiz değeri';it = 'Valore del parametro NomeProceduraOFunzione non valido.';de = 'Ungültiger Parameterwert ProcedureOrFunctionName.'"), Context);
	Validate(TypeOf(ParameterName) = Type("String"), 
		NStr("ru = 'Недопустимое значение параметра ParameterName'; en = 'Invalid value of ParameterName parameter.'; pl = 'Niedopuszczalna wartość parametrów ParameterName';es_ES = 'Valor inválido del parámetro ParameterName.';es_CO = 'Valor inválido del parámetro ParameterName.';tr = 'ParameterName parametresinin geçersiz değeri';it = 'Valore del parametro NomeParametro non valido.';de = 'Ungültiger Parameterwert ParameterName'"), Context);
		
	IsCorrectType = ExpectedTypeValue(ParameterValue, ExpectedTypes);
	Validate(IsCorrectType <> Undefined, 
		NStr("ru = 'Недопустимое значение параметра ExpectedTypes'; en = 'Invalid value of ExpectedTypes parameter.'; pl = 'Niedopuszczalna wartość parametrów ExpectedTypes';es_ES = 'Valor inválido del parámetro ExpectedTypes.';es_CO = 'Valor inválido del parámetro ExpectedTypes.';tr = 'ExpectedTypes parametresinin geçersiz değeri';it = 'Valore del parametro TipiAttesi non valido.';de = 'Ungültiger Parameterwert ErwarteteTypen'"), Context);
		
	InvalidParameter = NStr("ru = 'Недопустимое значение параметра %1 в %2. 
		|Ожидалось: %3; передано значение: %4 (тип %5).'; 
		|en = 'Invalid value for the %1 parameter in %2.
		|Expected value: %3, passed value: %4 (type: %5).'; 
		|pl = 'Niepoprawna wartość %1 parametru w %2. 
		|Oczekiwana: %3; wysłana wartość: %4 (typ %5).';
		|es_ES = 'Valor inválido del %1 parámetro en %2.
		|Esperado: %3; valor enviado: %4 (%5 tipo).';
		|es_CO = 'Valor inválido del %1 parámetro en %2.
		|Esperado: %3; valor enviado: %4 (%5 tipo).';
		|tr = '%1''deki %2 parametrenin geçersiz değeri.
		|Beklenen %5 ; gönderilen değer %3 (%4 tür).';
		|it = 'Valore del parametro %1 in %2 non valido.
		|Atteso: %3; valore immesso: %4 (tipo %5).';
		|de = 'Ungültiger Wert des %1 Parameters in %2.
		|Erwartet: %3; gesendeter Wert: %4 (%5Typ).'");
	Validate(IsCorrectType, StringFunctionsClientServer.SubstituteParametersToString(InvalidParameter,
		ParameterName,
		ProcedureOrFunctionName,
		TypesPresentation(ExpectedTypes), 
		?(ParameterValue <> Undefined, ParameterValue, NStr("ru = 'Неопределено'; en = 'Undefined'; pl = 'Nieokreślone';es_ES = 'No definido';es_CO = 'No definido';tr = 'Tanımlanmamış';it = 'Non definito';de = 'Nicht definiert'")),
		TypeOf(ParameterValue)));
			
	If TypeOf(ParameterValue) = Type("Structure") AND PropertiesTypesToExpect <> Undefined Then
		
		Validate(TypeOf(PropertiesTypesToExpect) = Type("Structure"), 
			NStr("ru = 'Недопустимое значение параметра ProcedureOrFunctionName'; en = 'Invalid value of ProcedureOrFunctionName parameter.'; pl = 'Niedopuszczalna wartość parametrów ProcedureOrFunctionName';es_ES = 'Valor inválido del parámetro ProcedureOrFunctionName.';es_CO = 'Valor inválido del parámetro ProcedureOrFunctionName.';tr = 'ProcedureOrFunctionName parametresinin geçersiz değeri';it = 'Valore del parametro NomeProceduraOFunzione non valido.';de = 'Ungültiger Parameterwert ProcedureOrFunctionName.'"), Context);
			
		NoProperty = NStr("ru = 'Недопустимое значение параметра %1 (Структура) в %2. 
			|В структуре ожидалось свойство %3 (тип %4).'; 
			|en = 'Invalid value of parameter %1 (Structure) in %2.
			|Expected value: %3 (type: %4).'; 
			|pl = 'Niepoprawna wartość parametru %1(Struktura) w %2. Oczekiwana właściwość 
			|%3 w strukturze (typ %4).';
			|es_ES = 'Valor del parámetro inválido %1 (Estructura) en %2. 
			|%3 propiedad se ha esperado en la estructura (tipo %4).';
			|es_CO = 'Valor del parámetro inválido %1 (Estructura) en %2. 
			|%3 propiedad se ha esperado en la estructura (tipo %4).';
			|tr = '%2'' de geçersiz parametre değeri %1 (Yapı). Yapıda (%4 tipi) 
			| %3 özellik beklenmiştir.';
			|it = 'Valore del parametro %1 (Struttura) in %2 non valido.
			|Nella struttura era attesa la proprietà %3 (tipo %4).';
			|de = 'Ungültiger Parameterwert %1 (Struktur) in%2.
			|%3 Eigenschaft wurde in der Struktur (%4Typ) erwartet.'");
		InvalidProperty = NStr("ru = 'Недопустимое значение свойства %1 в параметре %2 (Структура) в %3. 
			|Ожидалось: %4; передано значение: %5 (тип %6).'; 
			|en = 'Invalid value of property %1 in parameter %2 (Structure) in %3.
			|Expected value: %4; passed value: %5 (type: %6).'; 
			|pl = 'Niepoprawna %1 wartość właściwości w parametrze %2 (Struktura) w %3. 
			|Oczekiwana: %4; przekazana wartość: %5 (typ %6).';
			|es_ES = 'Valor de la propiedad %1 inválido en %2 el parámetro (Estructura) en %3. 
			|Esperado: %4; valor pasado: %5 (tipo %6).';
			|es_CO = 'Valor de la propiedad %1 inválido en %2 el parámetro (Estructura) en %3. 
			|Esperado: %4; valor pasado: %5 (tipo %6).';
			|tr = '%1''deki %2 parametre (Yapı) %3 öğesindeki geçersiz özellik değeri.
			| Beklenen:%4 ; iletilen değer: %5 (%6 tür).';
			|it = 'Valore della proprietà %1 nel parametro %2 (Struttura) in %3 non valido.
			|Atteso: %4; valore immesso: %5 (tipo %6).';
			|de = 'Ungültiger %1 Eigenschaftswert in %2 Parameter (Struktur) in %3.
			|Erwartet: %4; übergebener Wert: %5 (%6 Typ).'");
		For each Property In PropertiesTypesToExpect Do
			
			ExpectedPropertyName = Property.Key;
			ExpectedPropertyType = Property.Value;
			PropertyValue = Undefined;
			
			Validate(ParameterValue.Property(ExpectedPropertyName, PropertyValue), 
				StringFunctionsClientServer.SubstituteParametersToString(NoProperty, ParameterName, ProcedureOrFunctionName, 
					ExpectedPropertyName, ExpectedPropertyType));
				
			IsCorrectType = ExpectedTypeValue(PropertyValue, ExpectedPropertyType);
			Validate(IsCorrectType, StringFunctionsClientServer.SubstituteParametersToString(InvalidProperty, 
				ExpectedPropertyName,
				ParameterName,
				ProcedureOrFunctionName,
				TypesPresentation(ExpectedTypes), 
				?(PropertyValue <> Undefined, PropertyValue, NStr("ru = 'Неопределено'; en = 'Undefined'; pl = 'Nieokreślone';es_ES = 'No definido';es_CO = 'No definido';tr = 'Tanımlanmamış';it = 'Non definito';de = 'Nicht definiert'")),
				TypeOf(PropertyValue)));
		EndDo;
	EndIf;		
	
EndProcedure

// Returns empty UUID.
//
// Returns:
//  UUID - 00000000-0000-0000-0000-000000000000
//
Function BlankUUID() Export
	
	Return New UUID("00000000-0000-0000-0000-000000000000");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Math procedures and functions.

// Distributes the amount according to the specified distribution ratios.
// 
//
// Parameters:
//  AmountToDistribute - Number  - the amount to distribute. If set to 0, returns Undefined.
//                                 If set to a negative value, absolute value is calculated and then its sign is inverted.
//  Coefficients        - Array - distribution coefficients. All coefficients must be positive, or all coefficients must be negative.
//  Accuracy            - Number  - rounding accuracy during distribution. Optional.
//
// Returns:
//  Array - array whose dimension is equal to the number of coefficients, contains amounts according 
//           to the coefficient weights (from the array of coefficients).
//           If distribution cannot be performed (for example, number of coefficients = 0, or some 
//           coefficients are positive while some are negative, or total coefficient weight = 0), 
//           returns Undefined.
//
// Example:
//
//	Coefficients = New Array;
//	Coefficients.Add(1);
//	Coefficients.Add(2);
//	Result = CommonClientServer.DistributeAmountInProportionToCoefficients(1, Coefficients);
//	// Result = [0.33, 0.67]
//
Function DistributeAmountInProportionToCoefficients(Val AmountToDistribute, Val Coefficients, Val Accuracy = 2) Export
	
	AbsoluteCoefficients = New Array(New FixedArray(Coefficients)); // cpy
	
	// Keeping the old behavior in event of unspecified amount, for backward compatibility.
	If Not ValueIsFilled(AmountToDistribute) Then 
		Return Undefined;
	EndIf;
	
	If AbsoluteCoefficients.Count() = 0 Then 
		// Invalid value of the Coefficients parameter.
		// Expected that at least one coefficient is specified.
		Return Undefined;
	EndIf;
	
	MaxCoefficientIndex = 0;
	MaxCoefficient = 0;
	CoefficientSum = 0;
	NegativeCoefficients = (AbsoluteCoefficients[0] < 0);
	
	For Index = 0 To AbsoluteCoefficients.Count() - 1 Do
		Coefficient = AbsoluteCoefficients[Index];
		
		If NegativeCoefficients AND Coefficient > 0 Then 
			// Invalid value of the Coefficients parameter.
			// Expected that all coefficients are positive, or all coefficients are negative.
			Return Undefined;
		EndIf;
		
		If Coefficient < 0 Then 
			Coefficient = -Coefficient; // Abs(Coefficient)
			AbsoluteCoefficients[Index] = Coefficient; // move
		EndIf;
		
		If MaxCoefficient < Coefficient Then
			MaxCoefficient = Coefficient;
			MaxCoefficientIndex = Index;
		EndIf;
		
		CoefficientSum = CoefficientSum + Coefficient;
	EndDo;
	
	If CoefficientSum = 0 Then
		// Invalid value of the Coefficients parameter.
		// Expected that at least one coefficient is non-zero.
		Return Undefined;
	EndIf;
	
	Result = New Array(AbsoluteCoefficients.Count());
	
	Invert = (AmountToDistribute < 0);
	If Invert Then 
		AmountToDistribute = -AmountToDistribute; // Abs(AmountToDistribute).
	EndIf;
	
	DistributedAmount = 0;
	
	For Index = 0 To AbsoluteCoefficients.Count() - 1 Do
		Result[Index] = Round(AmountToDistribute * AbsoluteCoefficients[Index] / CoefficientSum, Accuracy, 1);
		DistributedAmount = DistributedAmount + Result[Index];
	EndDo;
	
	CombinedInaccuracy = AmountToDistribute - DistributedAmount;
	
	If CombinedInaccuracy > 0 Then 
		
		// Adding the round-off error to the ratio with the maximum weight.
		If Not DistributedAmount = AmountToDistribute Then
			Result[MaxCoefficientIndex] = Result[MaxCoefficientIndex] + CombinedInaccuracy;
		EndIf;
		
	ElsIf CombinedInaccuracy < 0 Then 
		
		// Spreading the inaccuracy to the nearest maximum weights if the distributed amount is too large.
		InaccuracyValue = 1 / Pow(10, Accuracy);
		InaccuracyItemCount = -CombinedInaccuracy / InaccuracyValue;
		
		For Cnt = 1 To InaccuracyItemCount Do 
			MaxCoefficient = MaxValueInArray(AbsoluteCoefficients);
			Index = AbsoluteCoefficients.Find(MaxCoefficient);
			Result[Index] = Result[Index] - InaccuracyValue;
			AbsoluteCoefficients[Index] = 0;
		EndDo;
		
	Else 
		// If CombinedInaccuracy = 0, everything is OK.
	EndIf;
	
	If Invert Then 
		For Index = 0 To AbsoluteCoefficients.Count() - 1 Do
			Result[Index] = -Result[Index];
		EndDo;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for managing external applications.

// Returns parameter structure. See the StartApplication procedure.
//
// Returns:
//  CurrentDirectory - String - current directory of the application to run.
//  WaitForCompletion - Boolean - True - wait for the running application to end before proceeding.
//      
//  GetOutputStream - Boolean - True - result is passed to stdout. Ignored if WaitForCompletion is 
//      not specified.
//  GetErrorStream - Boolean - True - errors are passed to stderr. Ignored if WaitForCompletion is 
//      not specified.
//  ExecuteWithFullRights - Boolean - True - the application must be run with full system privileges:
//      
//      - UAC confirmation for Windows.
//      - Interactive query with GUI sudo and forwarding
//      $DISPLAY and $XAUTHORITY of the current user for Linux.
//      Uncompatible with WaitForCompletion. Ignored when under MacOS.
//  Encoding - String - encoding code specified before the batch operation.
//      Ignored when under Linux or MacOS.
//
Function ApplicationStartupParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("CurrentDirectory", "");
	Parameters.Insert("WaitForCompletion", False);
	Parameters.Insert("GetOutputStream", False);
	Parameters.Insert("GetErrorStream", False);
	Parameters.Insert("ExecuteWithFullRights", False); // RunWithElevatedPermissions.
	Parameters.Insert("Encoding", "");
	
	Return Parameters;
	
EndFunction

// Runs an external application using the startup parameters.
// Not available in web client.
//
// Parameters:
//  StartupCommand - String, Array - application startup command line.
//      If Array, the first element is the path to the application, the rest of the elements are its 
//      startup parameters. The procedure generates an argv string from the array.
//  ApplicationStartupParameters - Structure - see the ApplicationStartupParameters function.
//
// Returns:
//  Structure - the application result.
//      ReturnCode - Number - the application return code.
//      OutputStream - String - the application result passed to stdout.
//      ErrorStream - String - the application errors passed to stderr.
//
// Example:
//	CommonClientServer.StartApplication("calc");
//	
//	ApplicationStartupParameters = CommonClientServer.ApplicationStartupParameters();
//	ApplicationStartupParameters.ExecuteWithFullRights = True;
//	CommonClientServer.StartApplication("C:\Program Files\1cv8\common\1cestart.exe", 
//		ApplicationStartupParameters);
//	
//	ApplicationStartupParameters = CommonClientServer.ApplicationStartupParameters();
//	ApplicationStartupParameters.WaitForCompletion = True;
//	Result = CommonClientServer.StartApplication("ping 127.0.0.1 -n 5", ApplicationStartupParameters);
//
Function StartApplication(Val StartupCommand, ApplicationStartupParameters = Undefined) Export 
	
#If WebClient OR MobileClient Then
	Raise NStr("ru = 'Запуск программ недоступен в веб-клиенте.'; en = 'Cannot run applications in the web client.'; pl = 'Uruchomienie programów jest niedostępne w Kliencie Web.';es_ES = 'El lanzamiento en el programa no está disponible en el cliente web.';es_CO = 'El lanzamiento en el programa no está disponible en el cliente web.';tr = 'Web işlemcide uygulama başlatılamadı.';it = 'L''avvio di programmi non è disponibile nel client web.';de = 'Das Ausführen von Programmen ist im Webclient nicht verfügbar.'");
#Else
	
	CommandString = SafeCommandString(StartupCommand);
	
	If ApplicationStartupParameters = Undefined Then 
		ApplicationStartupParameters = ApplicationStartupParameters();
	EndIf;
	
	CurrentDirectory              = ApplicationStartupParameters.CurrentDirectory;
	WaitForCompletion         = ApplicationStartupParameters.WaitForCompletion;
	GetOutputStream         = ApplicationStartupParameters.GetOutputStream;
	GetErrorStream         = ApplicationStartupParameters.GetErrorStream;
	ExecuteWithFullRights = ApplicationStartupParameters.ExecuteWithFullRights;
	Encoding                   = ApplicationStartupParameters.Encoding;
	
	If ExecuteWithFullRights Then 
#If ExternalConnection Then
		Raise 
			NStr("ru = 'Недопустимое значение параметра ApplicationStartupParameters.ExecuteWithFullRights.
			           |Повешение привилегий системы не доступно из внешнего соединения.'; 
			           |en = 'Invalid value of ApplicationStartupParameters.ExecuteWithFullRights parameter.
			           |Elevating system privileges is not supported in external connections.'; 
			           |pl = 'Niedopuszczalna wartość parametrów ApplicationStartupParameters.ExecuteWithFullRights.
			           |Zwiększenie przywilejów systemu nie jest dostępne z zewnętrznego połączenia.';
			           |es_ES = 'Valor inválido del parámetro ApplicationStartupParameters.ExecuteWithFullRights.
			           |Elevar los privilegios del sistema no es compatible con conexiones externas.';
			           |es_CO = 'Valor inválido del parámetro ApplicationStartupParameters.ExecuteWithFullRights.
			           |Elevar los privilegios del sistema no es compatible con conexiones externas.';
			           |tr = 'ApplicationStartupParameters.ExecuteWithFullRights parametresinin geçersiz değeri. 
			           | Sistem öncelikleri harici bağlantıdan yükseltilemez.';
			           |it = 'Valore non valido del parametro ApplicationStartupParameters.ExecuteWithFullRights.
			           |L''aumento dei privilegi di sistema non è supportato nelle connessioni esterne.';
			           |de = 'Ungültiger Parameterwert ParameterProgrammeStarten.AusführenMitHöchstenRechten.
			           |Die Erweiterung der Systemberechtigungen ist über eine externe Verbindung nicht verfügbar.'");
#EndIf
		
#If Server Then
		Raise 
			NStr("ru = 'Недопустимое значение параметра ApplicationStartupParameters.ExecuteWithFullRights.
			           |Повешение привилегий системы не доступно на сервере.'; 
			           |en = 'Invalid value of ApplicationStartupParameters.ExecuteWithFullRights parameter.
			           |Elevating system privileges is not supported on the server.'; 
			           |pl = 'Niedopuszczalna wartość parametrów ApplicationStartupParameters.ExecuteWithFullRights.
			           |Zwiększenie przywilejów systemu nie jest dostępne na serwerze.';
			           |es_ES = 'Valor inválido del parámetro ApplicationStartupParameters.ExecuteWithFullRights
			           |Elevar los privilegios del sistema no es compatible con el servidor.';
			           |es_CO = 'Valor inválido del parámetro ApplicationStartupParameters.ExecuteWithFullRights
			           |Elevar los privilegios del sistema no es compatible con el servidor.';
			           |tr = 'ApplicationStartupParameters.ExecuteWithFullRights parametresinin geçersiz değeri. 
			           | Sistem öncelikleri sunucudan yükseltilemez.';
			           |it = 'Valore non valido del parametro ApplicationStartupParameters.ExecuteWithFullRights.
			           |L''aumento dei privilegi di sistema non è supportato sul server.';
			           |de = 'Ungültiger Parameterwert ParameterProgrammeStarten.AusführenMitHöchstenRechten.
			           |Auf dem Server ist keine Erweiterung der Systemberechtigung verfügbar.'");
#EndIf
		
	EndIf;
	
	SystemInfo = New SystemInfo();
	If (SystemInfo.PlatformType = PlatformType.Windows_x86) 
		Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64) Then
	
		If Not IsBlankString(Encoding) Then
			CommandString = "chcp " + Encoding + " | " + CommandString;
		EndIf;
	
	EndIf;
	
	If WaitForCompletion Then 
		
		If GetOutputStream Then 
			OutputStreamFile = GetTempFileName("stdout.tmp");
			CommandString = CommandString + " > """ + OutputStreamFile + """";
		EndIf;
		
		If GetErrorStream Then 
			ErrorStreamFile = GetTempFileName("stderr.tmp");
			CommandString = CommandString + " 2>""" + ErrorStreamFile + """";
		EndIf;
		
	EndIf;
	
	ReturnCode = Undefined;
	
	If (SystemInfo.PlatformType = PlatformType.Windows_x86)
		Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64) Then
		
		// Because of the running through shell, redirect the directory with a command.
		If Not IsBlankString(CurrentDirectory) Then 
			CommandString = "cd /D """ + CurrentDirectory + """ && " + CommandString;
		EndIf;
		
		// Starting cmd.exe (for redirecting stdout and stderr).
		CommandString = "cmd /S /C "" " + CommandString + " """;
		
#If Server Then
		
		If Common.FileInfobase() Then
			// In a file infobase, the console window must be hidden in the server context as well.
			Shell = New COMObject("Wscript.Shell");
			ReturnCode = Shell.Run(CommandString, 0, WaitForCompletion);
			Shell = Undefined;
		Else 
			RunApp(CommandString,, WaitForCompletion, ReturnCode);
		EndIf;
		
#Else
		
		If ExecuteWithFullRights Then
			
			If WaitForCompletion Then
				Raise 
					NStr("ru = 'Недопустимо одновременно устанавливать параметры 
					           | - ApplicationStartupParameters.WaitForCompletionи
					           | - ApplicationStartupParameters.ExecuteWithFullRights:
					           |Операционная система не позволяет отслеживать от имени пользователя процессы,
					           |запущенные администратором.'; 
					           |en = 'Cannot set the following parameters simultaneously:
					           | - ApplicationStartupParameters.WaitForCompletion and
					           | - ApplicationStartupParameters.ExecuteWithFullRights
					           |Processes started by administrator
					           |cannot be monitored on behalf of user in this operating system.'; 
					           |pl = 'Niedopuszczalne jednoczesne ustanowienie parametrów 
					           | - ApplicationStartupParameters.WaitForCompletioni
					           | - ApplicationStartupParameters.ExecuteWithFullRights:
					           |System operacyjny nie pozwala obserwować w imieniu użytkownika procesy,
					           |uruchomione przez administratora.';
					           |es_ES = 'No se admite instalar simultáneamente los parámetros 
					           | - ApplicationStartupParameters.WaitForCompletion y
					           | - ApplicationStartupParameters.ExecuteWithFullRights:
					           |El sistema operativo no admite seguir del nombre de usuario los procesos
					           |lanzados por administrador.';
					           |es_CO = 'No se admite instalar simultáneamente los parámetros 
					           | - ApplicationStartupParameters.WaitForCompletion y
					           | - ApplicationStartupParameters.ExecuteWithFullRights:
					           |El sistema operativo no admite seguir del nombre de usuario los procesos
					           |lanzados por administrador.';
					           |tr = 'Parametreleri aynı anda belirlenemez:
					           |- ApplicationStartupParameters.WaitForCompletion ve - 
					           | ApplicationStartupParameters.ExecuteWithFullRights 
					           |İşletim sistemi, 
					           | yönetici tarafından başlatılan süreçlerin kullanıcı adına izlenmesine izin vermez.';
					           |it = 'Non è permesso impostare simultaneamente i parametri 
					           | - ParametriAvvioProgramma.AspettareTerminazione e 
					           | - ParametriAvvioProgramma.EseguireConPermessiMassimi:
					           |Il sistema operativo non permette agli utenti di monitorare i processi
					           |avviati dall''amministratore.';
					           |de = 'Nicht gleichzeitig Parameter einstellen
					           | - ParameterProgrammeStarten.WartenAufFertigstellung und
					           | - ParameterProgrammeStarten.AusführenMitHöchstenRechten.
					           |Das Betriebssystem erlaubt es nicht,
					           |die vom Administrator im Namen des Benutzers gestarteten Prozesse zu überwachen.'");
			EndIf;
			
			// After the start of the command file execution, it will be impossible to track the process status,
			// so you should delete the batch file by the last command line in the batch file.
			// You cannot delete asynchronously, otherwise a conflict may occur when an attempt to delete is 
			// made, and the start has not yet completed.
			
			CommandFile = GetTempFileName("runas.bat");
			WriteCommand = New TextWriter(CommandFile, TextEncoding.OEM);
			WriteCommand.WriteLine(CommandString);
			WriteCommand.WriteLine("del /f /q """ + CommandFile + """");
			WriteCommand.Close();
			
			Shell = New COMObject("Shell.Application");
			// Start with passing the action verb (increasing privileges).
			Shell.ShellExecute("cmd", "/c """ + CommandFile + """",, "runas", 0);
			Shell = Undefined;
			
		Else 
			Shell = New COMObject("Wscript.Shell");
			ReturnCode = Shell.Run(CommandString, 0, WaitForCompletion);
			Shell = Undefined;
		EndIf;
#EndIf
		
	ElsIf (SystemInfo.PlatformType = PlatformType.Linux_x86) 
		Or (SystemInfo.PlatformType = PlatformType.Linux_x86_64) Then
		
		If ExecuteWithFullRights Then
			
			CommandPattern = "pkexec env DISPLAY=[DISPLAY] XAUTHORITY=[XAUTHORITY] [CommandString]";
			
			TemplateParameters = New Structure;
			TemplateParameters.Insert("CommandString", CommandString);
			
			SubprogramStartupParameters = ApplicationStartupParameters();
			SubprogramStartupParameters.WaitForCompletion = True;
			SubprogramStartupParameters.GetOutputStream = True;
			
			Result = StartApplication("echo $DISPLAY", SubprogramStartupParameters);
			TemplateParameters.Insert("DISPLAY", Result.OutputStream);
			
			Result = StartApplication("echo $XAUTHORITY", SubprogramStartupParameters);
			TemplateParameters.Insert("XAUTHORITY", Result.OutputStream);
			
			CommandString = StringFunctionsClientServer.InsertParametersIntoString(CommandPattern, TemplateParameters);
			WaitForCompletion = True;
			
		EndIf;
		
		RunApp(CommandString, CurrentDirectory, WaitForCompletion, ReturnCode);
		
	Else
		
		// In case of MacOS just executing the command.
		// The ApplicationStartupParameters.ExecuteWithFullRights parameter is ignored.
		RunApp(CommandString, CurrentDirectory, WaitForCompletion, ReturnCode);
		
	EndIf;
	
	// Override the shell returned value.
	If ReturnCode = Undefined Then 
		ReturnCode = 0;
	EndIf;
	
	OutputStream = "";
	ErrorStream = "";
	
	If WaitForCompletion Then 
		
		If GetOutputStream Then
			
			FileInfo = New File(OutputStreamFile);
			If FileInfo.Exist() Then 
				OutputStreamReader = New TextReader(OutputStreamFile, StandardStreamEncoding()); 
				OutputStream = OutputStreamReader.Read();
				OutputStreamReader.Close();
				DeleteTempFile(OutputStreamFile);
			EndIf;
			
			If OutputStream = Undefined Then 
				OutputStream = "";
			EndIf;
			
		EndIf;
		
		If GetErrorStream Then 
			
			FileInfo = New File(ErrorStreamFile);
			If FileInfo.Exist() Then 
				ErrorStreamReader = New TextReader(ErrorStreamFile, StandardStreamEncoding());
				ErrorStream = ErrorStreamReader.Read();
				ErrorStreamReader.Close();
				DeleteTempFile(ErrorStreamFile);
			EndIf;
			
			If ErrorStream = Undefined Then 
				ErrorStream = "";
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Result = New Structure;
	Result.Insert("ReturnCode", ReturnCode);
	Result.Insert("OutputStream", OutputStream);
	Result.Insert("ErrorStream", ErrorStream);
	
	Return Result;
	
#EndIf
	
EndFunction

// Runs the network resource diagnostics.
// Not available in web client.
// In the SaaS mode, the functionality is limited to obtaining an error details.
//
// Parameters:
//  URL - String - URL resource address to be diagnosed.
//
// Returns:
//  Structure - the application result.
//      ErrorDescription    - String - a brief error description.
//      DiagnosticsLog - String - a detailed log of diagnostcs with texchnical details.
//
// Example:
//	// Diagnostics of address classifier web service.
//	Result = CommonClientServer. ConnectionDiagnostics ("https://api.orgaddress.1c.ru/orgaddress/v1?wsdl").
//	
//	ErrorDescription    = Result.ErrorDescription;
//	DiagnosticsLog = Result.DiagnosticsLog.
//
Function ConnectionDiagnostics(URL) Export
	
#If WebClient Then
	Raise NStr("ru = 'Выполнение диагностики соединения недоступно в веб-клиенте.'; en = 'The connection diagnostics are unavailable in the web client.'; pl = 'Wykonanie diagnostyki połączenia jest niedostępne w Kliencie Web.';es_ES = 'No está disponible la diagnóstica de la conexión en el cliente web.';es_CO = 'No está disponible la diagnóstica de la conexión en el cliente web.';tr = 'Bağlantı tanılama işlemi web istemcisinde kullanılamaz.';it = 'L''esecuzione della diagnostica di connessione non è disponibile nel client web.';de = 'Das Ausführen einer Diagnoseverbindung ist im Webclient nicht verfügbar.'");
#Else
	
	Details = New Array;
	Details.Add(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'При обращении по URL: %1'; en = 'Accessing URL: %1.'; pl = 'Podczas odwołania do URL: %1';es_ES = 'Al llamar por URL: %1';es_CO = 'Al llamar por URL: %1';tr = 'URL''ye erişirken: %1';it = 'Quando si accede all''URL: %1.';de = 'Beim Zugriff auf die URL: %1.'"), 
		URL));
	Details.Add(DiagnosticsLocationPresentation());
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Common.DataSeparationEnabled() Then
		Details.Add(
			NStr("ru = 'Обратитесь к администратору.'; en = 'Please contact the application administrator.'; pl = 'Skontaktuj się z administratorem.';es_ES = 'Contactar el administrador.';es_CO = 'Contactar el administrador.';tr = 'Yöneticiye başvurun.';it = 'Si prega di contattare l''amministratore dell''applicazione.';de = 'Kontaktieren Sie den Administrator.'"));
		
		ErrorDescription = StrConcat(Details, Chars.LF);
		
		Result = New Structure;
		Result.Insert("ErrorDescription", ErrorDescription);
		Result.Insert("DiagnosticsLog", "");
		
		Return Result;
	EndIf;
#EndIf
	
	Log = New Array;
	Log.Add(
		NStr("ru = 'Журнал диагностики:
		           |Выполняется проверка доступности сервера.
		           |Описание диагностируемой ошибки см. в следующем сообщении журнала.'; 
		           |en = 'Diagnostics log:
		           |Checking server availability.
		           |See the error description in the next log record.'; 
		           |pl = 'Dziennik diagnostyki:
		           |Jest wykonywana weryfikacja dostępności serwera.
		           |Opis wykrywanego błędu zob. w następnej wiadomości dziennika.';
		           |es_ES = 'El registro de diagnóstica:
		           |Se está realizando la prueba de disponibilidad del servidor.
		           |La descripción del error diagnosticado véase en el siguiente mensaje del registro.';
		           |es_CO = 'El registro de diagnóstica:
		           |Se está realizando la prueba de disponibilidad del servidor.
		           |La descripción del error diagnosticado véase en el siguiente mensaje del registro.';
		           |tr = 'Tanılama günlüğü: 
		           |sunucu kullanılabilirliğini denetler. 
		           |Teşhis edilen hatanın açıklaması için aşağıdaki günlük iletisine bakın.';
		           |it = 'Registro diagnostica:
		           |Verifica disponibilità server.
		           |Visualizzare la descrizione dell''errore nel prossimo registro degli eventi.';
		           |de = 'Diagnoseprotokoll:
		           |Die Verfügbarkeit des Servers wird überprüft.
		           |Die Beschreibung des zu diagnostizierenden Fehlers finden Sie in der folgenden Protokollnachricht.'"));
	Log.Add();
	
	ProxyConnection = False;
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadClientServer = 
			Common.CommonModule("GetFilesFromInternetClientServer");
		ProxySettingsStatus = ModuleNetworkDownloadClientServer.ProxySettingsStatus();
		
		ProxyConnection = ProxySettingsStatus.ProxyConnection;
		
		Log.Add(ProxySettingsStatus.Presentation);
	EndIf;
#Else
	If CommonClient.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		ModuleNetworkDownloadClientServer = 
			CommonClient.CommonModule("GetFilesFromInternetClientServer");
		ProxySettingsStatus = ModuleNetworkDownloadClientServer.ProxySettingsStatus();
		
		ProxyConnection = ProxySettingsStatus.ProxyConnection;
		
		Log.Add(ProxySettingsStatus.Presentation);
	EndIf;
#EndIf
	
	If ProxyConnection Then 
		
		Details.Add(
			NStr("ru = 'Диагностика соединения не выполнена, т.к. настроен прокси-сервер.
			           |Обратитесь к администратору.'; 
			           |en = 'Connection diagnostics are not performed because a proxy server is configured.
			           |Please contact the administrator.'; 
			           |pl = 'Diagnostyka połączenia nie jest wykonana, ponieważ jest ustawiony serwer proxy.
			           |Zwróć się do administratora.';
			           |es_ES = 'La diagnóstica de la conexión no se ha realizado porque está ajustado el servidor proxy.
			           |Diríjase al administrador.';
			           |es_CO = 'La diagnóstica de la conexión no se ha realizado porque está ajustado el servidor proxy.
			           |Diríjase al administrador.';
			           |tr = 'Proxy sunucusu yapılandırıldığından bağlantı tanılama başarısız oldu. 
			           |Lütfen sistem yöneticinize başvurun.';
			           |it = 'La diagnostica della connessione non è stata effettuata poiché è impostato un proxy-server.
			           |Rivolgetevi all''amministratore.';
			           |de = 'Die Diagnose der Verbindung wird nicht durchgeführt, da der Proxy-Server konfiguriert ist.
			           |Wenden Sie sich an den Administrator.'"));
		
	Else 
		
		RefStructure = URIStructure(URL);
		ResourceServerAddress = RefStructure.Host;
		VerificationServerAddress = "1c.com";
		
		ResourceAvailabilityResult = CheckServerAvailability(ResourceServerAddress);
		
		Log.Add();
		Log.Add("1) " + ResourceAvailabilityResult.DiagnosticsLog);
		
		If ResourceAvailabilityResult.Available Then 
			
			Details.Add(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Выполнено обращение к несуществующему ресурсу на сервере %1
				           |или возникли неполадки на удаленном сервере.'; 
				           |en = 'An attempt to access a nonexistent resource was made on server %1,
				           |or some issues occurred on the remote server.'; 
				           |pl = 'Zostało wykonane odwołanie do nie istniejącego zasobu na serwerze %1
				           |lub wystąpiły problemy na usuniętym serwerze.';
				           |es_ES = 'Se ha realizado la llamada al recurso no existente en el servidor%1
				           |o han aparecido los fallos en el servidor remoto.';
				           |es_CO = 'Se ha realizado la llamada al recurso no existente en el servidor%1
				           |o han aparecido los fallos en el servidor remoto.';
				           |tr = 'Sunucudaki mevcut olmayan kaynağa erişildi%1
				           |veya uzak sunucuda sorun yaşandı.';
				           |it = 'È stato effettuato un tentativo di accesso ad una risorsa non esistente sul server %1,
				           |oppure si è verificato un errore sul server remoto.';
				           |de = 'Der Verweis auf eine nicht vorhandene Ressource auf einem Server wird ausgeführt oder %1
				           |es gab Störungen auf einem entfernten Server.'"),
				ResourceServerAddress));
			
		Else 
			
			VerificationResult = CheckServerAvailability(VerificationServerAddress);
			Log.Add("2) " + VerificationResult.DiagnosticsLog);
			
			If Not VerificationResult.Available Then
				
				Details.Add(
					NStr("ru = 'Отсутствует доступ в сеть интернет по причине:
					           |- компьютер не подключен к интернету;
					           |- неполадки у интернет-провайдера;
					           |- подключение к интернету блокирует межсетевой экран, 
					           |  антивирусная программа или другое программное обеспечение.'; 
					           |en = 'No internet access. Possible reasons:
					           |- The computer is not connected to the internet.
					           | - Internet service provider issues.
					           |- A firewall, antivirus, or another software
					           |  is blocking the connection.'; 
					           |pl = 'Brakuje dostęp do sieci Internet z powodu:
					           |- komputer nie jest podłączony do Internetu;
					           |- problemy u operatora Internetu;
					           |- podłączenie do Internetu blokuje zapora sieciowa, 
					           |  program antiwirusowy lub inne oprogramowanie.';
					           |es_ES = 'No hay acceso en Internet a causa de:
					           |- el ordenador no está conectado a Internet;
					           |- los fallos del proveedor Internet;
					           |- la conexión a Internet bloqueo la pantalla entre red, 
					           |  el programa antivirus u otro software.';
					           |es_CO = 'No hay acceso en Internet a causa de:
					           |- el ordenador no está conectado a Internet;
					           |- los fallos del proveedor Internet;
					           |- la conexión a Internet bloqueo la pantalla entre red, 
					           |  el programa antivirus u otro software.';
					           |tr = 'Aşağıdakilerden dolayı İnternet erişimi yoktur: - 
					           |bilgisayar İnternete bağlı değildir - 
					           | İnternet sağlayıcısıyla ilgili sorunlar - 
					           |
					           | İnternet bağlantısı, güvenlik duvarı, antivirüs programı veya diğer yazılımlar tarafından engellendi.';
					           |it = 'Non c''è accesso a Internet a causa di:
					           |- il computer non è connesso a Internet;
					           |- ci sono problemi con il provider Internet;
					           |- la connessione Internet è bloccata dal firewall, 
					           |  dal programma antivirus o da un altro software.';
					           |de = 'Fehlender Zugang zum Internet aufgrund von:
					           |- der Computer ist nicht mit dem Internet verbunden;
					           |- Störungen beim Internet-Service-Provider;
					           |- Verbindung zum Internet blockiert die Firewall,
					           |das Antivirenprogramm oder andere Software.'"));
				
			Else 
				
				Details.Add(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Сервер %1 не доступен по причине:
					           |- неполадки у интернет-провайдера;
					           |- подключение к серверу блокирует межсетевой экран, 
					           |  антивирусная программа или другое программное обеспечение;
					           |- сервер отключен или на техническом обслуживании.'; 
					           |en = 'Server %1 is unavailable. Possible reasons: 
					           |-  Internet service provider issues.
					           |- A firewall, antivirus, or another software
					           |  is blocking the connection.
					           |- The server is turned off or under maintenance.'; 
					           |pl = 'Serwer %1 nie jest dostępny z powodu:
					           |- problemy u operatora Internetu;
					           |- podłączenie do serwisu blokuje zapora sieciowa, 
					           |  program antiwirusowy lub inne oprogramowanie;
					           |- serwer odłączony lub jest na konserwacji.';
					           |es_ES = 'El servidor %1 no está disponible a causa de:
					           |- los fallos del proveedor Internet;
					           |- la conexión a Internet bloqueo la pantalla entre red, 
					           |  el programa antivirus u otro software;
					           |- el servidor está desactivado o en el servicio técnico.';
					           |es_CO = 'El servidor %1 no está disponible a causa de:
					           |- los fallos del proveedor Internet;
					           |- la conexión a Internet bloqueo la pantalla entre red, 
					           |  el programa antivirus u otro software;
					           |- el servidor está desactivado o en el servicio técnico.';
					           |tr = 'Sunucuya%1 şu nedenlerden dolayı erişilemiyor: 
					           |- İnternet sağlayıcısıyla ilgili bir sorun; 
					           |- Sunucuyla bağlantı, güvenlik duvarı, 
					           |antivirüs veya diğer yazılımlar tarafından engellendi; 
					           |- Sunucunun bağlantısı kesildi veya bakım halinde.';
					           |it = 'Il server %1 non è disponibile a causa di:
					           |- ci sono problemi con il provider Internet;
					           |- la connessione Internet è bloccata dal firewall, 
					           |  dal programma antivirus o da un altro software;
					           | -il server è disattivato o in manutenzione.';
					           |de = 'Der Server %1 ist nicht verfügbar, weil:
					           |- eine Fehlfunktion des Internet-Service-Providers;
					           |- die Verbindung zum Server die Firewall,
					           |das Antivirenprogramm oder andere Software blockiert;
					           |- der Server deaktiviert ist oder sich in der Wartung befindet.'"),
					ResourceServerAddress));
				
				TraceLog = ServerRouteTraceLog(ResourceServerAddress);
				Log.Add("3) " + TraceLog);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ErrorDescription = StrConcat(Details, Chars.LF);
	
	Log.Insert(0);
	Log.Insert(0, ErrorDescription);
	
	DiagnosticsLog = StrConcat(Log, Chars.LF);
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	WriteLogEvent(
		NStr("ru = 'Диагностика соединения'; en = 'Connection diagnostics'; pl = 'Diagnostyka połączenia';es_ES = 'Diagnóstica de conexión';es_CO = 'Diagnóstica de conexión';tr = 'Bağlantı tanısı';it = 'Diagnostiche connessione';de = 'Verbindungsdiagnose'", DefaultLanguageCode()),
		EventLogLevel.Error,,, DiagnosticsLog);
#Else
	EventLogClient.AddMessageForEventLog(
		NStr("ru = 'Диагностика соединения'; en = 'Connection diagnostics'; pl = 'Diagnostyka połączenia';es_ES = 'Diagnóstica de conexión';es_CO = 'Diagnóstica de conexión';tr = 'Bağlantı tanısı';it = 'Diagnostiche connessione';de = 'Verbindungsdiagnose'", DefaultLanguageCode()),
		"Error", DiagnosticsLog,, True);
#EndIf
	
	Result = New Structure;
	Result.Insert("ErrorDescription", ErrorDescription);
	Result.Insert("DiagnosticsLog", DiagnosticsLog);
	
	Return Result;
	
#EndIf
	
EndFunction

// Creates a details object of OpenSSL secure connection.
// Parameters:
//  ClientCertificate - ClientCertificateFile,
//                      WindowsClientCertificate,
//                      Undefined - see OpenSSLSecureConnection.
//  CertificationAuthorityCertificates - FileCertificationAuthorityCertificates,
//                                     WindowsCertificationAuthorityCertificates,
//                                     LinuxCertificationAuthorityCertificates,
//                                     OSCertificationAuthorityCertificates,
//                                     Undefined - see OpenSSLSecureConnection.
//
// Returns:
//  OpenSSLSecureConnection - secure connection details.
//
Function NewSecureConnection(ClientCertificate = Undefined, CertificationAuthorityCertificates = Undefined) Export
	
	Return New OpenSSLSecureConnection(ClientCertificate, CertificationAuthorityCertificates);
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use CommonClientServer.ArraysDifference
// Calculates the difference between arrays. The difference between array A and array B is an array 
// that contains all elements from array A that are not present in array B.
//
// Parameters:
//  Array - Array - an array to subtract from.
//  SubtractionArray - Array - an array being subtracted.
// 
// Returns:
//  Array - the difference between array A and B.
//
Function ReduceArray(Array, SubtractionArray) Export
	
	Return ArraysDifference(Array, SubtractionArray);
	
EndFunction

#EndRegion

#EndRegion

#Region Private

// Searches for the item in the value list or in the array.
//
Function FindInList(List, Item)
	
	Var ItemInList;
	
	If TypeOf(List) = Type("ValueList") Then
		If TypeOf(Item) = Type("ValueListItem") Then
			ItemInList = List.FindByValue(Item.Value);
		Else
			ItemInList = List.FindByValue(Item);
		EndIf;
	EndIf;
	
	If TypeOf(List) = Type("Array") Then
		ItemInList = List.Find(Item);
	EndIf;
	
	Return ItemInList;
	
EndFunction

// Checks that email address does not contain border characters. If border characters is used 
// correctly, the procedure deletes them.
Function CheckAndPrepareEmailAddress(Val RecipientFullName, Val EmailAddress)
	
	ProhibitedCharInRecipientName = NStr("ru = 'Недопустимый символ в имени адресата.'; en = 'The recipient name contains a prohibited character.'; pl = 'Nazwa odbiorcy zawiera nieprawidłowe znaki.';es_ES = 'Nombre del destinatario contiene símbolos inválidos.';es_CO = 'Nombre del destinatario contiene símbolos inválidos.';tr = 'Alıcı adı geçersiz karakterler içeriyor.';it = 'Il nome del destinatario contiene un carattere vietato.';de = 'Der Empfängername enthält ungültige Zeichen.'");
	EmailContainsProhibitedChar = NStr("ru = 'Недопустимый символ в почтовом адресе.'; en = 'The email address contains a prohibited character.'; pl = 'Niedopuszczalny symbol w pocztowym adresie.';es_ES = 'Símbolo inválido en la dirección de envío de mensajes.';es_CO = 'Símbolo inválido en la dirección de envío de mensajes.';tr = 'Posta adresinde geçersiz karakter.';it = 'L''indirizzo email contiene un carattere vietato.';de = 'Ungültiges Zeichen in der Postanschrift'");
	BorderChars = "<>[]";
	
	EmailAddress     = TrimAll(EmailAddress);
	RecipientFullName = TrimAll(RecipientFullName);
	
	If StrStartsWith(RecipientFullName, "<") Then
		If StrEndsWith(RecipientFullName, ">") Then
			RecipientFullName = Mid(RecipientFullName, 2, StrLen(RecipientFullName)-2);
		Else
			Raise ProhibitedCharInRecipientName;
		EndIf;
	ElsIf StrStartsWith(RecipientFullName, "[") Then
		If StrEndsWith(RecipientFullName, "]") Then
			RecipientFullName = Mid(RecipientFullName, 2, StrLen(RecipientFullName)-2);
		Else
			Raise ProhibitedCharInRecipientName;
		EndIf;
	EndIf;
	
	If StrStartsWith(EmailAddress, "<") Then
		If StrEndsWith(EmailAddress, ">") Then
			EmailAddress = Mid(EmailAddress, 2, StrLen(EmailAddress)-2);
		Else
			Raise EmailContainsProhibitedChar;
		EndIf;
	ElsIf StrStartsWith(EmailAddress, "[") Then
		If StrEndsWith(EmailAddress, "]") Then
			EmailAddress = Mid(EmailAddress, 2, StrLen(EmailAddress)-2);
		Else
			Raise EmailContainsProhibitedChar;
		EndIf;
	EndIf;
	
	For Index = 1 To StrLen(BorderChars) Do
		If StrFind(RecipientFullName, Mid(BorderChars, Index, 1)) <> 0
		 OR StrFind(EmailAddress,     Mid(BorderChars, Index, 1)) <> 0 Then
			Raise EmailContainsProhibitedChar;
		EndIf;
	EndDo;
	
	Return New Structure("Address, Presentation", EmailAddress,RecipientFullName);
	
EndFunction

// Shifts a position marker while the current character is the SkippedChar. Returns number of marker 
// position.
//
Function SkipSpaces(Val Row,
                          Val CurrentIndex,
                          Val SkippedChar)
	
	// Removing skipped characters, if any.
	While CurrentIndex < StrLen(Row) Do
		If Mid(Row, CurrentIndex, 1) <> SkippedChar Then
			Return CurrentIndex;
		EndIf;
		CurrentIndex = CurrentIndex + 1;
	EndDo;
	
	Return CurrentIndex;
	
EndFunction

Procedure FindRecursively(ItemCollection, ItemArray, SearchMethod, SearchValue)
	
	For each FilterItem In ItemCollection Do
		
		If TypeOf(FilterItem) = Type("DataCompositionFilterItem") Then
			
			If SearchMethod = 1 Then
				If FilterItem.LeftValue = SearchValue Then
					ItemArray.Add(FilterItem);
				EndIf;
			ElsIf SearchMethod = 2 Then
				If FilterItem.Presentation = SearchValue Then
					ItemArray.Add(FilterItem);
				EndIf;
			EndIf;
		Else
			
			FindRecursively(FilterItem.Items, ItemArray, SearchMethod, SearchValue);
			
			If SearchMethod = 2 AND FilterItem.Presentation = SearchValue Then
				ItemArray.Add(FilterItem);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ReplaceCharsInStringWithSpaces(Row, CharsToReplace)
	Result = Row;
	For Position = 1 To StrLen(Chars) Do
		Result = StrReplace(Result, Mid(CharsToReplace, Position, 1), " ");
	EndDo;
	Return Result;
EndFunction

Function HasCharsLeftRight(Row, CharsToCheck)
	For Position = 1 To StrLen(CharsToCheck) Do
		Char = Mid(CharsToCheck, Position, 1);
		CharFound = (Left(Row,1) = Char) Or (Right(Row,1) = Char);
		If CharFound Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

Function StringContainsAllowedCharsOnly(Row, AllowedChars)
	CharactersArray = New Array;
	For Position = 1 To StrLen(AllowedChars) Do
		CharactersArray.Add(Mid(AllowedChars,Position,1));
	EndDo;
	
	For Position = 1 To StrLen(Row) Do
		If CharactersArray.Find(Mid(Row, Position, 1)) = Undefined Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

Function ExpectedTypeValue(Value, ExpectedTypes)
	ValueType = TypeOf(Value);
	If TypeOf(ExpectedTypes) = Type("TypeDescription") Then
		Return ExpectedTypes.Types().Find(ValueType) <> Undefined;
	ElsIf TypeOf(ExpectedTypes) = Type("Type") Then
		Return ValueType = ExpectedTypes;
	ElsIf TypeOf(ExpectedTypes) = Type("Array") Or TypeOf(ExpectedTypes) = Type("FixedArray") Then
		Return ExpectedTypes.Find(ValueType) <> Undefined;
	ElsIf TypeOf(ExpectedTypes) = Type("Map") Or TypeOf(ExpectedTypes) = Type("FixedMap") Then
		Return ExpectedTypes.Get(ValueType) <> Undefined;
	EndIf;
	Return Undefined;
EndFunction

Function TypesPresentation(ExpectedTypes)
	If TypeOf(ExpectedTypes) = Type("Array") Then
		Result = "";
		Index = 0;
		For Each Type In ExpectedTypes Do
			If Not IsBlankString(Result) Then
				Result = Result + ", ";
			EndIf;
			Result = Result + TypePresentation(Type);
			Index = Index + 1;
			If Index > 10 Then
				Result = Result + ",... "
					+ StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='(всего %1 типов)'; en = '(%1 types total)'; pl = '(łącznie %1 typów)';es_ES = '(total de %1 tipos)';es_CO = '(total de %1 tipos)';tr = '(toplam %1 tür)';it = '(%1 tipi totale)';de = '(insgesamt %1 Typen)'"), ExpectedTypes.Count());
				Break;	
			EndIf;	
		EndDo;
		Return Result;
	Else
		Return TypePresentation(ExpectedTypes);
	EndIf;
EndFunction

Function TypePresentation(Type)
	If Type = Undefined Then
		Return "Undefined";
	ElsIf TypeOf(Type) = Type("TypeDescription") Then
		TypeString = String(Type);
		Return ?(StrLen(TypeString) > 150, Left(TypeString, 150) + "..." 
			+ StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='(всего %1 типов)'; en = '(%1 types total)'; pl = '(łącznie %1 typów)';es_ES = '(total de %1 tipos)';es_CO = '(total de %1 tipos)';tr = '(toplam %1 tür)';it = '(%1 tipi totale)';de = '(insgesamt %1 Typen)'"), Type.Types().Count()), 
			TypeString);
	Else	
		TypeString = String(Type);
		Return ?(StrLen(TypeString) > 150, Left(TypeString, 150) + "...", TypeString);
	EndIf;	
EndFunction	

Function MaxValueInArray(Array)
	
	MaxValue = 0;
	
	For Index = 0 To Array.Count() - 1 Do
		Value = Array[Index];
		
		If MaxValue < Value Then
			MaxValue = Value;
		EndIf;
	EndDo;
	
	Return MaxValue;
	
EndFunction

Function SafeCommandString(StartupCommand) Export
	
	Result = "";
	
	If TypeOf(StartupCommand) = Type("String") Then 
		If ContainsUnsafeActions(StartupCommand) Then 
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Недопустимая строка команды
				           |%1
				           |по причине:
				           |Строка команды не должна содержать символы: ""$"", ""`"", ""|"", "";"", ""&"".'; 
				           |en = 'Invalid command line:
				           |%1.
				           | Reason:
				           |A command line cannot contain ""$"", ""`"", ""|"", "";"", and ""&"".'; 
				           |pl = 'Niedopuszczalny wiersz polecenia
				           |%1
				           |z powodu:
				           |Wiersz polecenia nie powinien zawierać symbole: ""$"", ""`"", ""|"", "";"", ""&"".';
				           |es_ES = 'Línea no admitida del comando
				           |%1
				           |a causa de:
				           |La línea del comando no debe contener los símbolos: ""$"", ""`"", ""|"", "";"", ""&"".';
				           |es_CO = 'Línea no admitida del comando
				           |%1
				           |a causa de:
				           |La línea del comando no debe contener los símbolos: ""$"", ""`"", ""|"", "";"", ""&"".';
				           |tr = 'Aşağıdaki nedenle geçersiz komut satırı 
				           |%1
				           |: 
				           |Komut satırı aşağıdaki sembolleri içermemelidir: ""$"", ""`"", ""|"", "";"", ""&"".';
				           |it = 'Riga di comando non valida:
				           |%1.
				           | Motivo:
				           | Una riga di comando non può contenere ""$"", ""`"", ""|"", "";"", e ""&"".';
				           |de = 'Ungültige Befehlszeile
				           |%1
				           |aufgrund von:
				           |Die Befehlszeile sollte nicht die folgenden Zeichen enthalten: ""$"", ""`"", ""|"", ""|"", "";"", ""&"".'"),
				StartupCommand);
		EndIf;
		
		Result = StartupCommand;
	ElsIf TypeOf(StartupCommand) = Type("Array") Then
		If StartupCommand.Count() > 0 Then 
			If ContainsUnsafeActions(StartupCommand[0]) Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Недопустимая команда или путь к исполняемому файлу
				           |%1
				           |по причине:
				           |Команды не должна содержать символы: ""$"", ""`"", ""|"", "";"", ""&"".'; 
				           |en = 'Invalid command or path to executable file:
				           |%1.
				           |. Reason:
				           |A command cannot contain ""$"", ""`"", ""|"", "";"", and ""&"".'; 
				           |pl = 'Niedopuszczalne polecenie lub droga do wykonywanego pliku
				           |%1
				           |z powodu:
				           |Polecenie nie powinno zawierać symbole: ""$"", ""`"", ""|"", "";"", ""&"".';
				           |es_ES = 'Comando no admitido o la ruta al archivo ejecutivo
				           |%1
				           |a causa de:
				           |El comando no debe contener los símbolos: ""$"", ""`"", ""|"", "";"", ""&"".';
				           |es_CO = 'Comando no admitido o la ruta al archivo ejecutivo
				           |%1
				           |a causa de:
				           |El comando no debe contener los símbolos: ""$"", ""`"", ""|"", "";"", ""&"".';
				           |tr = 'Aşağıdaki nedenle geçersiz komut veya yürütülebilir 
				           |%1
				           |dosya yolu nedeniyle: 
				           |komut aşağıdaki karakterleri içermemelidir: ""$"", ""`"", ""|"", "";"", ""&"".';
				           |it = 'Comando o percorso a file eseguibile non valido:
				           |%1.
				           | Motivo:
				           |Un comando non può contenere ""$"", ""`"", ""|"", "";"", e""&"".';
				           |de = 'Ungültiger Befehl oder Pfad zur ausführbaren Datei
				           |%1,
				           |weil:
				           |Befehle keine Symbole enthalten sollten: ""$"", ""`"", ""|"", ""|"", "";"", ""&"".'"),
				StartupCommand[0]);
			EndIf;
			Result = ArrayToCommandString(StartupCommand);
		Else
			Raise
				NStr("ru = 'Первый элемент StartupCommand должен быть командой или путем к исполняемому файлу.'; en = 'The first element of StartupCommand must be a command or a path to an executable file.'; pl = 'Był oczekiwany, że w pierwszym elemencie StartupCommand będzie poleceniem lub drogą do wykonywanego pliku.';es_ES = 'Se esperaba que el primer elemento StartupCommand será comando o ruta al archivo ejecutivo.';es_CO = 'Se esperaba que el primer elemento StartupCommand será comando o ruta al archivo ejecutivo.';tr = 'StartupCommand ilk öğenin bir komut veya yürütülebilir dosyaya yolu olması bekleniyor.';it = 'Il primo elemento di StartupCommand deve essere un comando o un percorso a un file eseguibile.';de = 'Es wurde erwartet, dass der BefehlStart im ersten Element ein Befehl oder ein Pfad zur ausführbaren Datei ist.'");
		EndIf;
	Else 
		Raise 
			NStr("ru = 'Тип StartupCommand должен быть ""String"" или ""Array""'; en = 'StartupCommand must have String or Array type.'; pl = 'Wartość StartupCommand mieć Wiersz lub Masyw.';es_ES = 'Se esperaba que el valor StartupCommand será Línea o Matriz';es_CO = 'Se esperaba que el valor StartupCommand será Línea o Matriz';tr = 'StartupCommand değerinin <Satır> veya <Masif> olması bekleniyordu';it = 'StartupCommand deve avere tipo Riga o Array.';de = 'Es wurde erwartet, dass der BefehlStart Zeichenfolge oder Feld ist'");
	EndIf;
		
	Return Result
	
EndFunction

Function ContainsUnsafeActions(Val CommandString)
	
	CommandString = StrReplace(CommandString, "$DISPLAY", "");
	CommandString = StrReplace(CommandString, "$XAUTHORITY", "");
	
	Return StrFind(CommandString, "$") <> 0
		Or StrFind(CommandString, "`") <> 0
		Or StrFind(CommandString, "|") <> 0
		Or StrFind(CommandString, ";") <> 0
		Or StrFind(CommandString, "&") <> 0;
	
EndFunction

Function ArrayToCommandString(StartupCommand)
	
	Result = New Array;
	QuotesRequired = False;
	For Each Argument In StartupCommand Do
		
		If Result.Count() > 0 Then 
			Result.Add(" ")
		EndIf;
		
		QuotesRequired = Argument = Undefined
			Or IsBlankString(Argument)
			Or StrFind(Argument, " ")
			Or StrFind(Argument, Chars.Tab)
			Or StrFind(Argument, "&")
			Or StrFind(Argument, "(")
			Or StrFind(Argument, ")")
			Or StrFind(Argument, "[")
			Or StrFind(Argument, "]")
			Or StrFind(Argument, "{")
			Or StrFind(Argument, "}")
			Or StrFind(Argument, "^")
			Or StrFind(Argument, "=")
			Or StrFind(Argument, ";")
			Or StrFind(Argument, "!")
			Or StrFind(Argument, "'")
			Or StrFind(Argument, "+")
			Or StrFind(Argument, ",")
			Or StrFind(Argument, "`")
			Or StrFind(Argument, "~")
			Or StrFind(Argument, "$")
			Or StrFind(Argument, "|");
		
		If QuotesRequired Then 
			Result.Add("""");
		EndIf;
		
		Result.Add(StrReplace(Argument, """", """"""));
		
		If QuotesRequired Then 
			Result.Add("""");
		EndIf;
		
	EndDo;
	
	Return StrConcat(Result);
	
EndFunction

Function PredefinedValueNotFoundErrorText(FullPredefinedItemName)
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Предопределенное значение ""%1"" не найдено.'; en = 'Predefined value ""%1"" is not found.'; pl = 'Predefiniowaną wartość ""%1"" nie znaleziono.';es_ES = 'Valor predeterminado ""%1"" no encontrado.';es_CO = 'Valor predeterminado ""%1"" no encontrado.';tr = 'Önceden tanımlanmış ""%1"" değeri bulunamadı.';it = 'Il valore predefinito ""%1"" non è stato trovato.';de = 'Vordefinierter Wert ""%1"" wurde nicht gefunden.'"), FullPredefinedItemName);
	
EndFunction

#If Not WebClient Then

// Returns encoding of standard output and error threads for the current operating system.
//
// Returns:
//  TextEncoding - encoding of standard output and error threads.
//
Function StandardStreamEncoding()
	
	SystemInfo = New SystemInfo();
	If (SystemInfo.PlatformType = PlatformType.Windows_x86) 
		Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64) Then
		
		Encoding = TextEncoding.OEM;
	Else
		Encoding = TextEncoding.System;
	EndIf;
	
	Return Encoding;
	
EndFunction

Procedure DeleteTempFile(FullFileName)
	
	If IsBlankString(FullFileName) Then
		Return;
	EndIf;
		
	Try
		DeleteFiles(FullFileName);
	Except
#If Server Then
		WriteLogEvent(NStr("ru = 'Базовая функциональность'; en = 'Basic functionality'; pl = 'Podstawowa funkcjonalność';es_ES = 'Funcionalidad básica';es_CO = 'Funcionalidad básica';tr = 'Esas işlevsellik';it = 'Funzionalità di base';de = 'Grundlegende Funktionalität'", DefaultLanguageCode()),
			EventLogLevel.Warning,,, 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось удалить временный файл
				           |%1 по причине: %2'; 
				           |en = 'Cannot delete temporary file:
				           |%1. Reason: %2'; 
				           |pl = 'Nie udało się usunąć plik tymczasowy
				           |%1 z powodu: %2';
				           |es_ES = 'No se ha podido eliminar el archivo temporal
				           |%1 a causa de: %2';
				           |es_CO = 'No se ha podido eliminar el archivo temporal
				           |%1 a causa de: %2';
				           |tr = 'Geçici dosya 
				           |%1 aşağıdaki nedenle silinemedi: %2';
				           |it = 'Non è possibile eliminare i file temporanei:
				           |%1. Motivo: %2';
				           |de = 'Die temporäre Datei
				           |%1 konnte aus diesem Grund nicht gelöscht werden: %2'"), 
				FullFileName, 
				BriefErrorDescription(ErrorInfo())));
#EndIf
	EndTry;
	
EndProcedure

Function DiagnosticsLocationPresentation()
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Common.DataSeparationEnabled() Then
		Return NStr("ru = 'Подключение проводится на сервере 1С:Предприятия в интернете.'; en = 'Connecting from a remote 1C:Enterprise server.'; pl = 'Podłączenie jest wykonywane na serwerze 1C:Enterprise.';es_ES = 'La conexión se realiza en el servidor 1C:Enterprise en internet.';es_CO = 'La conexión se realiza en el servidor 1C:Enterprise en internet.';tr = 'Bağlantı, 1C:İşletme sunucusunda İnternet''te yapılıyor.';it = 'Connesione da un server remoto 1C:Enterprise';de = 'Die Verbindung erfolgt auf dem Server 1C:Enterprises im Internet.'");
	Else 
		If Common.FileInfobase() Then
			If ClientConnectedOverWebServer() Then 
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Подключение проводится из файловой базы на веб-сервере <%1>.'; en = 'Connecting from a file infobase on web server <%1>.'; pl = 'Podłączenie jest wykonywane z bazy plikowej w serwisie internetowym <%1>.';es_ES = 'La conexión se realiza de la base de archivos en el servidor web <%1>.';es_CO = 'La conexión se realiza de la base de archivos en el servidor web <%1>.';tr = 'Bağlantı, web-sunucusundaki dosya tabanından yapılıyor <%1>.';it = 'Connessione da un file infobase sul server <%1>.';de = 'Die Verbindung wird von der Dateibasis auf dem Webserver <%1> hergestellt.'"), ComputerName());
			Else 
				Return StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Подключение проводится из файловой базы на компьютере <%1>.'; en = 'Connecting from a file infobase on computer <%1>.'; pl = 'Podłączenie jest wykonywane z bazy plikowej na komputerze <%1>.';es_ES = 'La conexión se realiza de la base de archivos en el ordenador <%1>.';es_CO = 'La conexión se realiza de la base de archivos en el ordenador <%1>.';tr = 'Bağlantı, bilgisayardaki dosya tabanından yapılıyor <%1>.';it = 'La connessione viene effettuata dal database di file sul computer <%1>.';de = 'Die Verbindung wird von der Dateibasis auf dem Computer <%1> hergestellt.'"), ComputerName());
			EndIf;
		Else
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Подключение проводится на сервере 1С:Предприятие <%1>.'; en = 'Connecting from 1C:Enterprise server <%1>.'; pl = 'Podłączenie jest wykonywane na serwerze 1C:Enterprise <%1>.';es_ES = 'La conexión se realiza en el servidor 1C:Enterprise <%1>.';es_CO = 'La conexión se realiza en el servidor 1C:Enterprise <%1>.';tr = 'Bağlantı, 1C:İşletme sunucusunda <%1> yapılıyor.';it = 'Connessione da un server 1C:Enterprise <%1>.';de = 'Die Verbindung wird auf dem Server 1C:Enterprise <%1> durchgeführt.'"), ComputerName());
		EndIf;
	EndIf;
#Else 
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Подключение проводится на компьютере (клиенте) <%1>.'; en = 'Connecting from computer <%1> (client).'; pl = 'Podłączenie jest wykonywane na komputerze (klienta) <%1>.';es_ES = 'La conexión se realiza en el ordenador (cliente) <%1>.';es_CO = 'La conexión se realiza en el ordenador (cliente) <%1>.';tr = 'Bağlantı, bilgisayarda (istemcide) yapılıyor <%1>.';it = 'Connessione da computer <%1> (client)';de = 'Die Verbindung wird auf dem Computer (Client) <%1> hergestellt.'"), ComputerName());
#EndIf
	
EndFunction

Function CheckServerAvailability(ServerAddress)
	
	ApplicationStartupParameters = ApplicationStartupParameters();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	
	SystemInfo = New SystemInfo();
	IsWindows = (SystemInfo.PlatformType = PlatformType.Windows_x86) 
		Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64);
		
	If IsWindows Then
		CommandPattern = "ping %1 -n 2 -w 500";
	Else
		CommandPattern = "ping -c 2 -w 500 %1";
	EndIf;
	
	CommandString = StringFunctionsClientServer.SubstituteParametersToString(CommandPattern, ServerAddress);
	
	Result = StartApplication(CommandString, ApplicationStartupParameters);
	
	// Different operating systems may display errors in different threads:
	// - Windows always displays errors in the output thread.
	// - Debian or RHEL displays errors in the error thread.
	AvailabilityLog = Result.OutputStream + Result.ErrorStream;
	
	If IsWindows Then
		UnavailabilityFact = (StrFind(AvailabilityLog, "Specified node unavailable") > 0)
			Or (StrFind(AvailabilityLog, "Destination host unreachable") > 0);
		
		NoLosses = (StrFind(AvailabilityLog, "(0% loss)") > 0)
			Or (StrFind(AvailabilityLog, "(0% loss)") > 0);
	Else 
		UnavailabilityFact = (StrFind(AvailabilityLog, "Destination Host Unreachable") > 0);
		NoLosses = (StrFind(AvailabilityLog, "0% packet loss") > 0)
	EndIf;
	
	Available = Not UnavailabilityFact AND NoLosses;
	AvailabilityState = ?(Available, NStr("ru = 'доступен'; en = 'is available'; pl = 'dostępny';es_ES = 'está disponible';es_CO = 'está disponible';tr = 'mevcut';it = 'E'' disponibile';de = 'verfügbar'"), NStr("ru = 'не доступен'; en = 'is unavailable'; pl = 'nie jest dostępny';es_ES = 'no está disponible';es_CO = 'no está disponible';tr = 'mevcut değil';it = 'non è disponibile';de = 'nicht verfügbar'"));
	
	Log = New Array;
	Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Удаленный сервер %1 %2:'; en = 'Remote server %1 %2:'; pl = 'Usunięty serwer %1 %2:';es_ES = 'Servidor remoto %1 %2:';es_CO = 'Servidor remoto %1 %2:';tr = 'Uzak sunucu %1 %2:';it = 'Server remoto %1 %2:';de = 'Remote-Server %1 %2:'"), 
		ServerAddress, 
		AvailabilityState));
	
	Log.Add("> " + CommandString);
	Log.Add(AvailabilityLog);
	
	Return New Structure("Available, DiagnosticsLog", Available, StrConcat(Log, Chars.LF));
	
EndFunction

Function ServerRouteTraceLog(ServerAddress)
	
	ApplicationStartupParameters = ApplicationStartupParameters();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	
	SystemInfo = New SystemInfo();
	IsWindows = (SystemInfo.PlatformType = PlatformType.Windows_x86) 
		Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64);
	
	If IsWindows Then
		CommandPattern = "tracert -w 100 -h 15 %1";
	Else 
		// If the traceroute package is not installed, an error will occur in the output tread.
		// As the result will not be parsed, you can ignore the output thread.
		// According to it the administrator will understand what to do.
		CommandPattern = "traceroute -w 100 -m 100 %1";
	EndIf;
	
	CommandString = StringFunctionsClientServer.SubstituteParametersToString(CommandPattern, ServerAddress);
	
	Result = StartApplication(CommandString, ApplicationStartupParameters);
	
	Log = New Array;
	Log.Add(StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Трассировка маршрута к удаленному серверу %1:'; en = 'Tracing route to remote server %1:'; pl = 'Trasowanie trasy do do usuniętego serwera %1:';es_ES = 'Trazabilidad de la ruta al servidor remoto %1:';es_CO = 'Trazabilidad de la ruta al servidor remoto %1:';tr = '%1 Uzak sunucuya rota izleme:';it = 'Tracciando percorso al server remoto %1:';de = 'Verfolgung der Route zum Remote-Server %1:'"), ServerAddress));
	
	Log.Add("> " + CommandString);
	Log.Add(Result.OutputStream);
	Log.Add(Result.ErrorStream);
	
	Return StrConcat(Log, Chars.LF);
	
EndFunction

#EndIf

#EndRegion
