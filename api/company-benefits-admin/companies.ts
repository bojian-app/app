import type { RouteRecordRaw } from 'vue-router';
const view = () => import('#/views/operations/index.vue');
const routes: RouteRecordRaw[] = [{
 name:'Companies',path:'/companies',meta:{title:'企业福利',icon:'lucide:building-2',order:32,authority:['admin:benefits:read','admin:*']},
 children:[
  {name:'CompanyBenefits',path:'benefits',component:view,meta:{title:'平台收录',authority:['admin:benefits:read','admin:*']}},
  {name:'CompanyBenefitSubmissions',path:'submissions',component:view,meta:{title:'收录审核',authority:['admin:benefits:review','admin:*']}},
 ],
}];
export default routes;
