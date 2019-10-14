
namespace Utopia
{
    public enum EAppState
    {
        Invalid = 0,
        Init, // ���ֳ�ʼ��
        MainLogic, // �������߼�
        Quit, // �˳�
        WaitTask, // �ȴ�����

        Count,
    }

    public class AppStateBase : IState<EAppState>
    {
        public AppStateMgr stateMgr { get; protected set; }
        public AppStateBase() : base(null, 0) { }
        public AppStateBase(AppStateMgr _stateMgr, EAppState id) : base(_stateMgr, id)
        {
            stateMgr = _stateMgr;
        }
        public override void Enter(object param)
        {
        }

        public override void Exit()
        {
        }

        public override void Update()
        {
        }
    }
}

