#Region Private

// Returns a value of an additional order attribute for a new object.
//
// Parameters:
//  Information - Structure - information on object metadata.
//  Parent   - Ref    - a reference to the object parent.
//  Owner   - Ref    - a reference to the object owner.
//
// Returns:
//  Number - a value of an additional order attribute.
Function GetNewAdditionalOrderingAttributeValue(Information, Parent, Owner) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query();
	
	QueryConditions = New Array;
	
	If Information.HasParent Then
		QueryConditions.Add("Table.Parent = &Parent");
		Query.SetParameter("Parent", Parent);
	EndIf;
	
	If Information.HasOwner Then
		QueryConditions.Add("Table.Owner = &Owner");
		Query.SetParameter("Owner", Owner);
	EndIf;
	
	AdditionalConditions = "TRUE";
	For Each Condition In QueryConditions Do
		AdditionalConditions = AdditionalConditions + " AND " + Condition;
	EndDo;
	
	QueryText =
	"SELECT TOP 1
	|	Table.AdditionalOrderingAttribute AS AdditionalOrderingAttribute
	|FROM
	|	&Table AS Table
	|WHERE
	|	&AdditionalConditions
	|
	|ORDER BY
	|	AdditionalOrderingAttribute DESC";
	
	QueryText = StrReplace(QueryText, "&Table", Information.FullName);
	QueryText = StrReplace(QueryText, "&AdditionalConditions", AdditionalConditions);
	
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return ?(Not ValueIsFilled(Selection.AdditionalOrderingAttribute), 1, Selection.AdditionalOrderingAttribute + 1);
	
EndFunction

Function CheckItemsOrdering(TableMetadata)
	If Not AccessRight("Update", TableMetadata) Then
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	QueryText = 
	"SELECT
	|	&Owner AS Owner,
	|	&Parent AS Parent,
	|	Table.AdditionalOrderingAttribute AS AdditionalOrderingAttribute,
	|	1 AS Count,
	|	Table.Ref AS Ref
	|INTO AllItems
	|FROM
	|	&Table AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AllItems.Owner,
	|	AllItems.Parent,
	|	AllItems.AdditionalOrderingAttribute,
	|	SUM(AllItems.Count) AS Count
	|INTO IndexStatistics
	|FROM
	|	AllItems AS AllItems
	|
	|GROUP BY
	|	AllItems.AdditionalOrderingAttribute,
	|	AllItems.Parent,
	|	AllItems.Owner
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IndexStatistics.Owner,
	|	IndexStatistics.Parent,
	|	IndexStatistics.AdditionalOrderingAttribute
	|INTO Duplicates
	|FROM
	|	IndexStatistics AS IndexStatistics
	|WHERE
	|	IndexStatistics.Count > 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AllItems.Ref AS Ref
	|FROM
	|	AllItems AS AllItems
	|		INNER JOIN Duplicates AS Duplicates
	|		ON AllItems.AdditionalOrderingAttribute = Duplicates.AdditionalOrderingAttribute
	|			AND AllItems.Parent = Duplicates.Parent
	|			AND AllItems.Owner = Duplicates.Owner
	|
	|UNION ALL
	|
	|SELECT
	|	AllItems.Ref
	|FROM
	|	AllItems AS AllItems
	|WHERE
	|	AllItems.AdditionalOrderingAttribute = 0";
	
	Information = ItemOrderSetup.GetInformationForMoving(TableMetadata);
	
	QueryText = StrReplace(QueryText, "&Table", Information.FullName);
	
	ParentField = "Parent";
	If Not Information.HasParent Then
		ParentField = "1";
	EndIf;
	QueryText = StrReplace(QueryText, "&Parent", ParentField);
	
	OwnerField = "Owner";
	If Not Information.HasOwner Then
		OwnerField = "1";
	EndIf;
	QueryText = StrReplace(QueryText, "&Owner", OwnerField);
	
	Query = New Query(QueryText);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return False;
	EndIf;
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.AdditionalOrderingAttribute = 0;
		Try
			Object.Write();
		Except
			Continue;
		EndTry;
	EndDo;
	
	Return True;
	
EndFunction

Function MoveItem(ItemList, CurrentItemRef, Direction) Export
	
	AccessParameters = AccessParameters("Update", CurrentItemRef.Metadata(), "Ref");
	If Not AccessParameters.Accessibility Then
		Return NStr("ru = '???????????????????????? ???????? ?????? ?????????????????? ?????????????? ??????????????????.'; en = 'You are not authorized to change the item sequence'; pl = 'Nie masz wystarczaj??cych uprawnie??, aby zmieni?? kolejno???? element??w.';es_ES = 'Insuficientes derechos para cambiar el orden de art??culos.';es_CO = 'Insuficientes derechos para cambiar el orden de art??culos.';tr = '????e s??ras??n?? de??i??tirmek i??in yetersiz haklar.';it = 'Permessi insufficienti per modificare l''ordine degli elementi';de = 'Unzureichende Rechte, um die Reihenfolge der Artikel zu ??ndern.'");
	EndIf;
	
	Information = ItemOrderSetup.GetInformationForMoving(CurrentItemRef.Metadata());
	DataCompositionSettings = ItemList.GetPerformingDataCompositionSettings();
	
	// For hierarchical catalogs, you can set filter by parent. If this filter is not set, the display 
	// method must be hierarchical or as a tree.
	RepresentedAsList = ItemList.Representation = TableRepresentation.List;
	If Information.HasParent AND RepresentedAsList AND Not ListContainsFilterByParent(DataCompositionSettings) Then
		Return NStr("ru = '?????? ?????????????????? ?????????????? ?????????????????? ???????????????????? ???????????????????? ?????????? ?????????????????? ""????????????"" ?????? ""?????????????????????????? ????????????"".'; en = 'To be able to change the item sequence, set the view mode to Tree or Hierarchical list.'; pl = 'Aby zmieni?? kolejno???? element??w, ustaw tryb wy??wietlania ""Drzewo"" lub ""Lista hierarchiczna"".';es_ES = 'Para cambiar la secuencia de art??culos, establecer el modo de vista ""??rbol"" o ""Lista jer??rquica"".';es_CO = 'Para cambiar la secuencia de art??culos, establecer el modo de vista ""??rbol"" o ""Lista jer??rquica"".';tr = '????e s??ras??n?? de??i??tirmek i??in ""A??a??"" veya ""Hiyerar??ik liste"" g??r??nt??leme modunu ayarlay??n.';it = 'Per modificare l''ordine degli elementi ?? necessario passare alla modalit?? di visualizzazione ""Albero"" oppure ""Elenco Gerarchico"".';de = 'Um die Objektfolge zu ??ndern, stellen Sie den Ansichtsmodus ""Baum"" oder ""Hierarchische Liste"" ein.'");
	EndIf;
	
	// For subordinate catalogs, filter by owner is to be set.
	If Information.HasOwner AND Not ListContainsFilterByOwner(DataCompositionSettings) Then
		Return NStr("ru = '?????? ?????????????????? ?????????????? ?????????????????? ???????????????????? ???????????????????? ?????????? ???? ???????? ""????????????????"".'; en = 'To be able to change the item sequence, filter the list by the Owner field.'; pl = 'Aby zmieni?? kolejno???? towaru, nale??y ustawi?? filtr wed??ug pola ""W??a??ciciel"".';es_ES = 'Para cambiar la secuencia de art??culos, establecer el filtro por el campo ""Propietario"".';es_CO = 'Para cambiar la secuencia de art??culos, establecer el filtro por el campo ""Propietario"".';tr = '????e s??ras??n?? de??i??tirmek i??in filtreyi ""Sahip"" alan??na g??re ayarlay??n.';it = 'Per modificare l''ordine degli elementi ?? necessario impostare la selezione secondo il campo ""Proprietario"".';de = 'Um die Objektfolge zu ??ndern, legen Sie den Filter nach dem Feld ""Besitzer"" fest.'");
	EndIf;
	
	// Checking the Use flag of the AdditionalOrderingAttribute attribute for the item to be moved.
	If Information.HasGroups Then
		IsFolder = Common.ObjectAttributeValue(CurrentItemRef, "IsFolder");
		If IsFolder AND Not Information.ForGroups Or Not IsFolder AND Not Information.ForItems Then
			Return NStr("ru = '?????????????????? ?????????????? ???????????? ????????????????????.'; en = 'Cannot move the selected item.'; pl = 'Wybrana pozycja nie mo??e by?? przeniesiona.';es_ES = 'El art??culos seleccionado no puede transferirse.';es_CO = 'El art??culos seleccionado no puede transferirse.';tr = 'Se??ilen ????e aktar??lamaz.';it = 'Impossibile spostare l''elemento selezionato.';de = 'Der ausgew??hlte Artikel kann nicht ??bertragen werden.'");
		EndIf;
	EndIf;
	
	CheckItemsOrdering(CurrentItemRef.Metadata());
	
	DataCompositionSettings = ItemList.GetPerformingDataCompositionSettings();
	ErrorText = CheckSortingInList(DataCompositionSettings);
	If Not IsBlankString(ErrorText) Then
		Return ErrorText;
	EndIf;
	
	DataCompositionGroup = DataCompositionSettings.Structure[0];
	
	DataCompositionField = DataCompositionGroup.Selection.SelectionAvailableFields.Items.Find("Ref").Field;
	HasFieldRef = False;
	For Each DataCompositionSelectedField In DataCompositionGroup.Selection.Items Do
		If DataCompositionSelectedField.Field = DataCompositionField Then
			HasFieldRef = True;
			Break;
		EndIf;
	EndDo;
	If Not HasFieldRef Then
		DataCompositionSelectedField = DataCompositionGroup.Selection.Items.Add(Type("DataCompositionSelectedField"));
		DataCompositionSelectedField.Use = True;
		DataCompositionSelectedField.Field = DataCompositionField;
	EndIf;
	
	DataCompositionSchema = ItemList.GetPerformingDataCompositionScheme();
	ValuesTree = ExecuteQuery(DataCompositionSchema, DataCompositionSettings);
	If ValuesTree = Undefined Then
		Return NStr("ru = '?????? ?????????????????? ?????????????? ?????????????????? ???????????????????? ???????????????? ?????????????????? ????????????
			|(???????? ?????? - ???????????????????? ?????????????????????? ??????????????????).'; 
			|en = 'To change the item sequence, reset the list settings
			| (Menu More - Use standard settings).'; 
			|pl = 'W celu zmiany porz??dku element??w nale??y zresetowa?? ustawienia listy
			|(Menu Jeszcze - Ustaw ustawienia standardowe).';
			|es_ES = 'Para cambiar el orden de los elementos es necesario restablecer los ajustes de la lista
			|(Men?? M??s - Establecer los ajustes est??ndares).';
			|es_CO = 'Para cambiar el orden de los elementos es necesario restablecer los ajustes de la lista
			|(Men?? M??s - Establecer los ajustes est??ndares).';
			|tr = '????e d??zenini de??i??tirmek i??in liste ayarlar?? s??f??rlanmal??d??r
			|(Men?? Daha fazla - Standart ayarlar?? yap).';
			|it = 'Per modificare l''ordine degli elementi ?? necessario ripristinare le impostazioni dell''elenco
			|(Menu Altro - Impostare le impostazioni di default).';
			|de = 'Um die Reihenfolge der Elemente zu ??ndern, m??ssen Sie die Listeneinstellungen zur??cksetzen
			|(Men?? Mehr- Standardeinstellungen festlegen).'");
	EndIf;
	
	ValueTreeRow = ValuesTree.Rows.Find(CurrentItemRef, "Ref", True);
	Parent = ValueTreeRow.Parent;
	If Parent = Undefined Then
		Parent = ValuesTree;
	EndIf;
	
	CurrentItemIndex = Parent.Rows.IndexOf(ValueTreeRow);
	NeighborItemIndex = CurrentItemIndex;
	If Direction = "Up" Then
		If CurrentItemIndex > 0 Then
			NeighborItemIndex = CurrentItemIndex - 1;
		EndIf;
	Else // Down
		If CurrentItemIndex < Parent.Rows.Count() - 1 Then
			NeighborItemIndex = CurrentItemIndex + 1;
		EndIf;
	EndIf;
	
	If CurrentItemIndex <> NeighborItemIndex Then
		NeighborRow = Parent.Rows.Get(NeighborItemIndex);
		NeighborItemRef = NeighborRow.Ref;
		
		Items = New Array;
		Items.Add(CurrentItemRef);
		Items.Add(NeighborItemRef);
		
		SwapItems(CurrentItemRef, NeighborItemRef);
	EndIf;
	
	Return "";
EndFunction

Function ExecuteQuery(DataCompositionSchema, DataCompositionSettings)
	
	Result = New ValueTree;
	TemplateComposer = New DataCompositionTemplateComposer;
	Try
		DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema,
			DataCompositionSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	Except
		ErrorMessageText = BriefErrorDescription(ErrorInfo());
		Return Undefined;
	EndTry;
	
	DataCompositionProcessor = New DataCompositionProcessor;
	DataCompositionProcessor.Initialize(DataCompositionTemplate);
	
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(Result);
	OutputProcessor.Output(DataCompositionProcessor);
	
	Return Result;
EndFunction

Procedure SwapItems(FirstItemRef, SecondItemRef)
	
	BeginTransaction();
	Try
		LockDataForEdit(FirstItemRef);
		LockDataForEdit(SecondItemRef);
		
		FirstItemObject = FirstItemRef.GetObject();
		SecondItemObject = SecondItemRef.GetObject();
		
		FirstItemIndex = FirstItemObject.AdditionalOrderingAttribute;
		SecondItemIndex = SecondItemObject.AdditionalOrderingAttribute;
		
		FirstItemObject.AdditionalOrderingAttribute = SecondItemIndex;
		SecondItemObject.AdditionalOrderingAttribute = FirstItemIndex;
	
		FirstItemObject.Write();
		SecondItemObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function CheckSortingInList(DataCompositionSettings)
	
	OrderItems = DataCompositionSettings.Order.Items;
	
	AdditionalOrderFields = New Array;
	AdditionalOrderFields.Add(New DataCompositionField("AdditionalOrderField1"));
	AdditionalOrderFields.Add(New DataCompositionField("AdditionalOrderField2"));
	AdditionalOrderFields.Add(New DataCompositionField("AdditionalOrderField3"));
	
	Item = Undefined;
	For Each OrderItem In OrderItems Do
		If OrderItem.Use Then
			Item = OrderItem;
			If AdditionalOrderFields.Find(Item.Field) <> Undefined Then
				Continue;
			EndIf;
			Break;
		EndIf;
	EndDo;
	
	SortingCorrect = False;
	If Item <> Undefined AND TypeOf(Item) = Type("DataCompositionOrderItem") Then
		If Item.OrderType = DataCompositionSortDirection.Asc Then
			AttributeField = New DataCompositionField("AdditionalOrderingAttribute");
			If Item.Field = AttributeField Then
				SortingCorrect = True;
			EndIf;
		EndIf;
	EndIf;
	
	AdditionalOrderingAttribute = DataCompositionSettings.Order.OrderAvailableFields.FindField(New DataCompositionField("AdditionalOrderingAttribute"));
	If Not SortingCorrect Then
		Return StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '?????? ?????????????????????? ?????????????????? ???????????????????? ?????????????????? ????????????????????
			|?? ???????????? ???? ???????? ""%1"" (???? ??????????????????????)'; 
			|en = 'To transfer items, set up sorting in the 
			|list by the ""%1"" field (ascending)'; 
			|pl = 'W celu przemieszczenia element??w nale??y ustawi?? sortowanie
			|w li??cie wed??ug pola ""%1"" (rosn??co)';
			|es_ES = 'Para trasladar los elementos es necesario ajustar la clasificaci??n 
			|en la lista por el campo ""%1"" (en orden ascendente)';
			|es_CO = 'Para trasladar los elementos es necesario ajustar la clasificaci??n 
			|en la lista por el campo ""%1"" (en orden ascendente)';
			|tr = '????eleri ta????mak i??in listeyi 
			|""%1"" alan??na g??re s??ralay??n (artan)';
			|it = 'Per spostare gli elementi ?? necessario configurare il sorting
			|nell''elenco secondo il campo ""%1"" (in ordine crescente)';
			|de = 'Um Elemente zu verschieben, sollten Sie eine Sortierung
			|in der Liste nach dem Feld ""%1"" einrichten (in aufsteigender Reihenfolge)'"), AdditionalOrderingAttribute.Title);
	EndIf;
	
	Return "";
	
EndFunction

Function ListContainsFilterByOwner(DataCompositionSettings)
	
	RequiredFilters = New Array;
	RequiredFilters.Add(New DataCompositionField("Owner"));
	RequiredFilters.Add(New DataCompositionField("Owner"));
	
	Return HasRequiredFilter(DataCompositionSettings.Filter, RequiredFilters);
	
EndFunction

Function ListContainsFilterByParent(DataCompositionSettings)
	
	RequiredFilters = New Array;
	RequiredFilters.Add(New DataCompositionField("Parent"));
	RequiredFilters.Add(New DataCompositionField("Parent"));
	
	Return HasRequiredFilter(DataCompositionSettings.Filter, RequiredFilters);
	
EndFunction

Function HasRequiredFilter(FiltersCollection, RequiredFilters)
	
	For Each Filter In FiltersCollection.Items Do
		If TypeOf(Filter) = Type("DataCompositionFilterItemGroup") Then
			FilterFound = HasRequiredFilter(Filter, RequiredFilters);
		Else
			FilterFound = RequiredFilters.Find(Filter.LeftValue) <> Undefined;
		EndIf;
		
		If FilterFound Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction


#EndRegion
