unit SubscribersU;

interface

uses
  System.RTTI, CommonsU;

type

  TSubscriberMethod = class(TObject)
  private
    FEventType: TClass;
    FThreadMode: TThreadMode;
    FPriority: Integer;
    FMethod: TRttiMethod;
    procedure SetEventType(const Value: TClass);
    procedure SetMethod(const Value: TRttiMethod);
    procedure SetPriority(const Value: Integer);
    procedure SetThreadMode(const Value: TThreadMode);
  public
    constructor Create(ARttiMethod: TRttiMethod; AEventType: TClass;
      AThreadMode: TThreadMode; APriority: Integer = 1);
    destructor Destroy; override;
    property EventType: TClass read FEventType write SetEventType;
    property Method: TRttiMethod read FMethod write SetMethod;
    property ThreadMode: TThreadMode read FThreadMode write SetThreadMode;
    property Priority: Integer read FPriority write SetPriority;
    function Equals(Obj: TObject): Boolean; override;
  end;

  TSubscription = class(TObject)
  private
    FSubscriberMethod: TSubscriberMethod;
    FSubscriber: TObject;
    FActive: Boolean;
    procedure SetActive(const Value: Boolean);
    function GetActive: Boolean;
    procedure SetSubcriberMethod(const Value: TSubscriberMethod);
    procedure SetSubscriber(const Value: TObject);
  public
    constructor Create(ASubscriber: TObject;
      ASubscriberMethod: TSubscriberMethod);
    destructor Destroy; override;
    property Active: Boolean read GetActive write SetActive;
    property Subscriber: TObject read FSubscriber write SetSubscriber;
    property SubscriberMethod: TSubscriberMethod read FSubscriberMethod
      write SetSubcriberMethod;
    function Equals(Obj: TObject): Boolean; override;

  end;

  TSubscribersFinder = class(TObject)
    class function FindSubscriberMethods(ASubscriberClass: TClass;
      ARaiseExcIfEmpty: Boolean = false): TArray<TSubscriberMethod>;
  end;

implementation

uses
  AttributesU, RTTIUtilsU, System.SysUtils;

{ TSubscriberMethod }

constructor TSubscriberMethod.Create(ARttiMethod: TRttiMethod;
  AEventType: TClass; AThreadMode: TThreadMode; APriority: Integer);
begin
  FMethod := ARttiMethod;
  FEventType := AEventType;
  FThreadMode := AThreadMode;
  FPriority := APriority;
end;

destructor TSubscriberMethod.Destroy;
begin
  inherited;
end;

function TSubscriberMethod.Equals(Obj: TObject): Boolean;
var
  OtherSubscriberMethod: TSubscriberMethod;
begin
  if (inherited Equals(Obj)) then
    exit(true)
  else if (Obj is TSubscriberMethod) then
  begin
    OtherSubscriberMethod := TSubscriberMethod(Obj);
    exit(OtherSubscriberMethod.Method.ToString = Method.ToString);
  end
  else
    exit(false);
end;

procedure TSubscriberMethod.SetEventType(const Value: TClass);
begin
  FEventType := Value;
end;

procedure TSubscriberMethod.SetMethod(const Value: TRttiMethod);
begin
  FMethod := Value;
end;

procedure TSubscriberMethod.SetPriority(const Value: Integer);
begin
  FPriority := Value;
end;

procedure TSubscriberMethod.SetThreadMode(const Value: TThreadMode);
begin
  FThreadMode := Value;
end;

{ TSubscribersFinder }

class function TSubscribersFinder.FindSubscriberMethods(ASubscriberClass
  : TClass; ARaiseExcIfEmpty: Boolean = false): TArray<TSubscriberMethod>;
var
  LRttiContext: TRttiContext;
  LRttiType: TRttiType;
  LSubscribeAttribute: SubscribeAttribute;
  LRttiMethods: TArray<System.RTTI.TRttiMethod>;
  LMethod: TRttiMethod;
  LParamsLength: Integer;
  LEventType: TClass;
begin
  LRttiType := LRttiContext.GetType(ASubscriberClass);
  LRttiMethods := LRttiType.GetMethods;
  for LMethod in LRttiMethods do
    if TRTTIUtils.HasAttribute<SubscribeAttribute>(LMethod, LSubscribeAttribute)
    then
    begin
      LParamsLength := Length(LMethod.GetParameters);
      if (LParamsLength <> 1) then
        raise Exception.CreateFmt
          ('Method  %s has Subscribe attribute but requires %d arguments. Methods must require a single argument.',
          [LMethod.Name, LParamsLength]);
      LEventType := LMethod.GetParameters[0].ParamType.Handle.TypeData.
        ClassType;
      Result := Result + [TSubscriberMethod.Create(LMethod, LEventType,
        LSubscribeAttribute.ThreadMode)];
    end;
  if (Length(Result) < 1) then
    raise Exception.CreateFmt
      ('The class %s and its super classes have no public methods with the Subscribe attributes',
      [ASubscriberClass.QualifiedClassName]);
end;

{ TSubscription }

constructor TSubscription.Create(ASubscriber: TObject;
  ASubscriberMethod: TSubscriberMethod);
begin
  inherited Create;
  FSubscriber := ASubscriber;
  FSubscriberMethod := ASubscriberMethod;
  FActive := true;
end;

destructor TSubscription.Destroy;
begin
  if Assigned(FSubscriberMethod) then
    FreeAndNil(FSubscriberMethod);
  if Assigned(FSubscriber) then
    FreeAndNil(FSubscriber);
  inherited;
end;

function TSubscription.Equals(Obj: TObject): Boolean;
var
  LOtherSubscription: TSubscription;
begin
  if (Obj is TSubscription) then
  begin
    LOtherSubscription := TSubscription(Obj);
    exit((Subscriber = LOtherSubscription.Subscriber) and
      (SubscriberMethod.Equals(LOtherSubscription.SubscriberMethod)));
  end
  else
    exit(false);
end;

function TSubscription.GetActive: Boolean;
begin
  TMonitor.Enter(self);
  try
    Result := FActive;
  finally
    TMonitor.exit(self);
  end;
end;

procedure TSubscription.SetActive(const Value: Boolean);
begin
  TMonitor.Enter(self);
  try
    FActive := Value;
  finally
    TMonitor.exit(self);
  end;
end;

procedure TSubscription.SetSubcriberMethod(const Value: TSubscriberMethod);
begin
  FSubscriberMethod := Value;
end;

procedure TSubscription.SetSubscriber(const Value: TObject);
begin
  FSubscriber := Value;
end;

end.