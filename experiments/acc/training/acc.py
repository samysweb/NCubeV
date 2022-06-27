"""
Linear Adaptive Cruise Control in Relative Coordinates.
The visualization fixes the position of the leader car.
From N. Fulton and A. Platzer,
"Safe Reinforcement Learning via Formal Methods: Toward Safe Control through Proof and Learning",
AAAI 2018.

OpenAI Gym implementation adapted from the classic control cart pole environment.
"""

import logging
import math
import gym
from gym import spaces
from gym.utils import seeding
import numpy as np
import random

import polytope as pc

from polytope.solvers import lpsolve
def cheby_ball(poly1):
    #logger.debug('cheby ball')
    if (poly1._chebXc is not None) and (poly1._chebR is not None):
        # In case chebyshev ball already calculated and stored
        return poly1._chebR, poly1._chebXc
    if isinstance(poly1, pc.Region):
        maxr = 0
        maxx = None
        for poly in poly1.list_poly:
            rc, xc = cheby_ball(poly)
            if rc > maxr:
                maxr = rc
                maxx = xc
        poly1._chebXc = maxx
        poly1._chebR = maxr
        return maxr, maxx
    if pc.is_empty(poly1):
        return 0, None
    # `poly1` is nonempty
    r = 0
    xc = None
    A = poly1.A
    c = np.negative(np.r_[np.zeros(np.shape(A)[1]), 1])
    norm2 = np.sqrt(np.sum(A * A, axis=1))
    G = np.c_[A, norm2]
    h = poly1.b
    sol = lpsolve(c, G, h)
    #return sol
    if sol['status'] == 0 or (sol['status'] == 4 and pc.is_inside(poly1,sol['x'][0:-1])):
        r = sol['x'][-1]
        if r < 0:
            return 0, None
        xc = sol['x'][0:-1]
    else:
        # Polytope is empty
        poly1 = pc.Polytope(fulldim=False)
        return 0, None
    poly1._chebXc = np.array(xc)
    poly1._chebR = np.double(r)
    return poly1._chebR, poly1._chebXc


logger = logging.getLogger(__name__)

class ACCEnv(gym.Env):
    metadata = {
        'render.modes': ['human', 'rgb_array'],
        'video.frames_per_second' : 50
    }

    def is_crash(self, some_state):
      return some_state[0] <= 1

    def __init__(self):
        # Makes the continuous fragment of the system determinitic by fixing the
        # amount of time that the ODE evolves.
        self.TIME_STEP = 0.1

        # The maximum separation between the leader and follower before the
        # state becomes a terminal state.
        self.MAX_VALUE = 100

        # The rates at which the vehicle's velocities change when increasing
        # and closing the relative distance, respectively. B will be negative
        # when action = 0.
        self.A = 100
        self.B = 100

        # Obsoleted; just need to figure out how the observation space
        # works...
        # Angle at which to fail the episode
        self.theta_threshold_radians = 12 * 2 * math.pi / 360
        self.x_threshold = 2.4

        # Angle limit set to 2 * theta_threshold_radians so failing observation is still within bounds
        high = np.array([
            #self.x_threshold * 2,
            np.finfo(np.float32).max,
            #self.theta_threshold_radians * 2,
            np.finfo(np.float32).max])

        self.action_space = spaces.Box(-self.B,self.A,shape=(1,)) # acc = -,0,+
        self.observation_space = spaces.Box(-high, high)

        self._seed()
        self.viewer = None
        self.state = None

        self.steps_beyond_done = None

    def _seed(self, seed=None):
        self.np_random, seed = seeding.np_random(seed)
        return [seed]

    # def _acc_from_action(self, action):
    #   """Comptes the choice of acceleration from a discrete sample space -- ACC, 0, DECEL.
    #      Choice of acceleration will be return_value * TIME_STEP "meters/second".
    #   """
    #   assert self.action_space.contains(action), "%r (%s) invalid"%(action, type(action))
    #   #print "Action is: " , action
    #   if(action == 0):
    #     return -self.B
    #   elif(action == 1):
    #     return 0
    #   elif(action == 2):
    #     return self.A

    FAULT_RATE = 0.0
    ERROR_MAGNITUDE = 0.0
    def _step(self, action):
        assert self.FAULT_RATE != None and self.ERROR_MAGNITUDE != None, "FAULT_RATE and ERROR_MAGNITUDE should be initialized %s, %s" % (self.FAULT_RATE, self.ERROR_MAGNITUDE)

        if (random.uniform(0, 1) >= self.FAULT_RATE):
            return self._stepByModel(action)
        else:
            assert False


    def _stepByModel(self, action):
        assert self.action_space.contains(action), "%s (of type %s) invalid" % (str(action), type(action))
        state = self.state

        # x is the relative distance between the leader and the follower.
        pos, vel = state[0],state[1]

        # update velocity by integrating the new acceleration over time --
        # vel = acc*t + vel_0, pos = acc*t^2/2 + vel_0*t + pos_0
        t = self.TIME_STEP
        
        # Determine new acceleration based upon the chosen action.
        acc = action[0]
        #print "Choice of acceleration is: " , acc * self.TIME_STEP , " m/s"

        # x'=v,v'=a
        pos_0 = pos
        vel_0 = vel
        vel = acc*t + vel_0
        pos = acc*t**2/2 + vel_0*t + pos_0

        self.state = (pos, vel)
        #print "[env/acc.py] state after _step is: ", self.state

        done = self.is_crash(self.state) or self.state[0] > self.MAX_VALUE
        done = bool(done)

        if not done:
            reward = 1.0
        elif done and self.state[0] <= 1:
            #print("TOO CLOSE")
            reward = -200.0
        elif done and self.state[0] > self.MAX_VALUE - 0.5:
            #print("TOO FAR")
            reward = -100.0
        else:
            assert False, "Not sure why this should happen, and when it was previously there was a bug in the if/elif guards..."
            reward = 0.0

        return np.array(self.state), reward, done, {'crash': self.state[0] <= 0}

    def _reset(self):
        pos = self.np_random.uniform(low=5, high=75, size=(1,))[0]
        #vel = self.np_random.uniform(low=-pos/3, high=15, size=(1,))[0]
        # pos >= vel^2 / (2*A)
        min_velocity = -np.sqrt(pos*2*self.A)
        # Hypothetical constraint on the other side:
        # (MAX_VALUE-pos) <= vel^2 / (2*B)
        max_velocity = np.sqrt((self.MAX_VALUE-pos)*2*self.B)
        vel = self.np_random.uniform(low=min_velocity,high=max_velocity, size=(1,))[0]
        self.state = (pos, vel)
        #print("Starting separated by ", pos, " meters moving at ", vel, " m/s.")

        self.steps_beyond_done = None
        return np.array(self.state)

    def _render(self, mode='human', close=False):
        if close:
            if self.viewer is not None:
                self.viewer.close()
                self.viewer = None
            return

        screen_width = 1000
        screen_height = 800

        world_width = self.x_threshold*2
        scale = screen_width/world_width
        carty = 100 # TOP OF CART
        polewidth = 10.0
        polelen = scale * 1.0
        cartwidth = 5.0
        cartheight = 30.0

        relativeDistance = cartwidth * 2

        if self.viewer is None:
            from gym.envs.classic_control import rendering
            self.viewer = rendering.Viewer(screen_width, screen_height)
           
            # Add a follower cart.
            l,r,t,b = -cartwidth/2, cartwidth/2, cartheight/2, -cartheight/2
            cart = rendering.FilledPolygon([(l,b), (l,t), (r,t), (r,b)])
            self.carttrans = rendering.Transform()
            cart.add_attr(self.carttrans)
            self.viewer.add_geom(cart)

            # Add a leader cart
            l,r,t,b = -cartwidth/2 + relativeDistance, cartwidth/2 + relativeDistance, cartheight/2, -cartheight/2
            cart2 = rendering.FilledPolygon([(l,b), (l,t), (r,t), (r,b)])
            self.carttrans2 = rendering.Transform()
            cart2.add_attr(self.carttrans2)
            self.viewer.add_geom(cart2)
            
            # Display a track.
            self.track = rendering.Line((0,carty), (screen_width,carty))
            self.track.set_color(0,0,0)
            self.viewer.add_geom(self.track)

            #TODO screen_width - 100 = fixed position of the leader car.
            self.max_line = rendering.Line((screen_width - 100 - self.MAX_VALUE, 0), (screen_width - 100 - self.MAX_VALUE, 200))
            self.max_line.set_color(0,0,0)
            self.viewer.add_geom(self.max_line)

        if self.state is None: return None

        relativeDistance, relativeVelocity = self.state
        followerx = screen_width - 100 - relativeDistance
        leaderx = screen_width - 100
        #cartx = x[0]*scale+screen_width/2.0 # MIDDLE OF CART
        self.carttrans.set_translation(followerx, carty)
        self.carttrans2.set_translation(leaderx, carty)

        return self.viewer.render(return_rgb_array = mode=='rgb_array')


class ACCEnv2(gym.Env):
    metadata = {
        'render.modes': ['human', 'rgb_array'],
        'video.frames_per_second' : 50
    }

    def is_crash(self, some_state):
      return some_state[0] <= 0

    def __init__(self):
        # Makes the continuous fragment of the system determinitic by fixing the
        # amount of time that the ODE evolves.
        self.TIME_STEP = 0.1

        # The maximum separation between the leader and follower before the
        # state becomes a terminal state.
        self.MAX_VALUE = 200

        # The rates at which the vehicle's velocities change when increasing
        # and closing the relative distance, respectively. B will be negative
        # when action = 0.
        self.A = 100
        self.B = 100

        # Obsoleted; just need to figure out how the observation space
        # works...
        # Angle at which to fail the episode
        self.theta_threshold_radians = 12 * 2 * math.pi / 360
        self.x_threshold = 2.4

        # Angle limit set to 2 * theta_threshold_radians so failing observation is still within bounds
        high = np.array([
            #self.x_threshold * 2,
            np.finfo(np.float32).max,
            #self.theta_threshold_radians * 2,
            np.finfo(np.float32).max])

        self.action_space = spaces.Box(-1.0,1.0,shape=(1,)) # acc = -,0,+
        self.observation_space = spaces.Box(-high, high)

        self.MODEL_RESET_SHARE = 1.0
        self.POLYTOPES = None
        self.POLYTOPE_VOLUMES = None
        self.INCLUDE_UNWINNABLE = True

        self._seed()
        self.viewer = None
        self.state = None

        self.steps_beyond_done = None

    def _seed(self, seed=None):
        self.np_random, seed = seeding.np_random(seed)
        return [seed]

    # def _acc_from_action(self, action):
    #   """Comptes the choice of acceleration from a discrete sample space -- ACC, 0, DECEL.
    #      Choice of acceleration will be return_value * TIME_STEP "meters/second".
    #   """
    #   assert self.action_space.contains(action), "%r (%s) invalid"%(action, type(action))
    #   #print "Action is: " , action
    #   if(action == 0):
    #     return -self.B
    #   elif(action == 1):
    #     return 0
    #   elif(action == 2):
    #     return self.A

    FAULT_RATE = 0.0
    ERROR_MAGNITUDE = 0.0
    def _step(self, action):
        assert self.FAULT_RATE != None and self.ERROR_MAGNITUDE != None, "FAULT_RATE and ERROR_MAGNITUDE should be initialized %s, %s" % (self.FAULT_RATE, self.ERROR_MAGNITUDE)

        if (random.uniform(0, 1) >= self.FAULT_RATE):
            return self._stepByModel(action)
        else:
            assert False
            #print "[env/acc] INJECTING ERROR"
            state, reward, done, infos = self._stepByModel(action)
            state[0] = state[0] - self.ERROR_MAGNITUDE
            self.state = state

            #COPY PASTA
            done = self.is_crash(self.state) or self.state[0] > self.MAX_VALUE
            done = bool(done)
            if not done:
                reward = 1.0
            elif done and self.state[0] <= 1:
                reward = -100.0
            elif done and self.state[0] > self.MAX_VALUE - 0.5:
                reward = -100.0
            else:
                assert False, "Not sure why this should happen, and when it was previously there was a bug in the if/elif guards..."
                reward = 0.0

            return state, reward, done, infos


    def _stepByModel(self, action):
        assert self.action_space.contains(action), "%s (of type %s) invalid" % (str(action), type(action))
        state = self.state

        # x is the relative distance between the leader and the follower.
        pos, vel = state[0],state[1]

        # update velocity by integrating the new acceleration over time --
        # vel = acc*t + vel_0, pos = acc*t^2/2 + vel_0*t + pos_0
        t = self.TIME_STEP
        
        # Determine new acceleration based upon the chosen action.
        acc = action[0]
        if acc>0:
            acc = self.A*acc
        else:
            acc = self.B*acc
        acc = np.clip(acc, -self.B, self.A)
        #print "Choice of acceleration is: " , acc * self.TIME_STEP , " m/s"

        # x'=v,v'=a
        pos_0 = pos
        vel_0 = vel
        vel = acc*t + vel_0
        pos = acc*t**2/2 + vel_0*t + pos_0

        self.state = (pos, vel)
        #print "[env/acc.py] state after _step is: ", self.state

        done = self.is_crash(self.state) or self.state[0] > self.MAX_VALUE
        done = bool(done)

        if not done:
            # Reward as little acceleration as possible.
            reward= 10*(1.0-abs(action[0]))
        elif done and self.state[0] <= 1:
            #print("TOO CLOSE")
            reward = -2000.0
        elif done and self.state[0] > self.MAX_VALUE - 0.5:
            #print("TOO FAR")
            reward = -800.0
        else:
            assert False, "Not sure why this should happen, and when it was previously there was a bug in the if/elif guards..."
            reward = 0.0

        return np.array(self.state), reward, done, {'crash': self.state[0] <= 0}

    def _reset(self):
        self.steps = 0
        r = self.np_random.uniform(low=0.0, high=1.0, size=(1,))[0]
        if r <= self.MODEL_RESET_SHARE:
            return self.model_reset()
        else:
            return self.polytope_reset()

    def model_reset(self):
        choice = self.np_random.uniform(low=1,high=10)
        pos = self.np_random.uniform(low=4, high=95, size=(1,))[0]
        if choice <= 2 and self.INCLUDE_UNWINNABLE:
            vel = -np.sqrt(pos*2*self.A)
        else:
            # pos >= vel^2 / (2*A)
            if self.INCLUDE_UNWINNABLE:
                if pos < 10:
                    min_velocity = -np.sqrt(pos*2*self.A)
                else:
                    min_velocity = -100
                max_velocity = 100
            else:
                min_velocity = -np.sqrt(pos*2*self.A)+1e-3
                max_velocity = np.sqrt((self.MAX_VALUE-pos)*2*self.B)-1e-3
            vel = self.np_random.uniform(low=min_velocity,high=max_velocity, size=(1,))[0]
        self.state = (pos, vel)
        #print("Starting separated by ", pos, " meters moving at ", vel, " m/s.")

        self.steps_beyond_done = None
        return np.array(self.state)
    
    def init_polytopes(self, model_share, polytopes):
        self.MODEL_RESET_SHARE = model_share
        volume = []
        for p in polytopes:
            volume.append(pc.volume(p))
        total_volume = sum(volume)
        
        self.POLYTOPE_VOLUMES = [0]
        for v in volume:
            self.POLYTOPE_VOLUMES.append((self.POLYTOPE_VOLUMES[-1]*total_volume + v)/total_volume)
        self.POLYTOPES = []
        for p in polytopes:
            cheby_ball(p)
            self.POLYTOPES.append(p)

    def sample_from_poly(self):
        while True:
            #print(">", end="")
            r = self.np_random.uniform(low=0.0, high=1.0, size=(1,))[0]
            poly = self.POLYTOPES[-1]
            # TODO(steuber): Could be more efficient through binary search
            for i in range(len(self.POLYTOPE_VOLUMES)):
                if r > self.POLYTOPE_VOLUMES[i]:
                    poly = self.POLYTOPES[i-1]
            l_b, u_b = poly.bounding_box
            l_b = l_b.flatten()
            u_b = u_b.flatten()
            x = None
            n = poly.A.shape[1]
            for i in range(400):
                #print(".", end="")
                x = self.np_random.uniform(low=l_b,high=u_b,size=(n,))
                if x in poly:
                    break
            # Fallback if random sampling doesn't work
            if x is None:
                x = poly.chebXc
            # Fallback if polytope looks empty
            if x is None:
                continue
            return x
    
    def polytope_reset(self):
        while True:
            #print("|",end="")
            res = self.sample_from_poly()
            if -np.sqrt(res[0]*2*self.A)+1e-3<=res[1] and res[1]<=np.sqrt((self.MAX_VALUE-res[0])*2*self.B)-1e-3 and not (self.is_crash(res) or res[0] > self.MAX_VALUE):
                self.state = res
                rv = res
                break
        #print("Starting separated by ", rv[0], " meters moving at ", rv[1], " m/s.")
        return rv

    def _render(self, mode='human', close=False):
        if close:
            if self.viewer is not None:
                self.viewer.close()
                self.viewer = None
            return

        screen_width = 1000
        screen_height = 800

        world_width = self.x_threshold*2
        scale = screen_width/world_width
        carty = 100 # TOP OF CART
        polewidth = 10.0
        polelen = scale * 1.0
        cartwidth = 5.0
        cartheight = 30.0

        relativeDistance = cartwidth * 2

        if self.viewer is None:
            from gym.envs.classic_control import rendering
            self.viewer = rendering.Viewer(screen_width, screen_height)
           
            # Add a follower cart.
            l,r,t,b = -cartwidth/2, cartwidth/2, cartheight/2, -cartheight/2
            cart = rendering.FilledPolygon([(l,b), (l,t), (r,t), (r,b)])
            self.carttrans = rendering.Transform()
            cart.add_attr(self.carttrans)
            self.viewer.add_geom(cart)

            # Add a leader cart
            l,r,t,b = -cartwidth/2 + relativeDistance, cartwidth/2 + relativeDistance, cartheight/2, -cartheight/2
            cart2 = rendering.FilledPolygon([(l,b), (l,t), (r,t), (r,b)])
            self.carttrans2 = rendering.Transform()
            cart2.add_attr(self.carttrans2)
            self.viewer.add_geom(cart2)
            
            # Display a track.
            self.track = rendering.Line((0,carty), (screen_width,carty))
            self.track.set_color(0,0,0)
            self.viewer.add_geom(self.track)

            #TODO screen_width - 100 = fixed position of the leader car.
            self.max_line = rendering.Line((screen_width - 100 - self.MAX_VALUE, 0), (screen_width - 100 - self.MAX_VALUE, 200))
            self.max_line.set_color(0,0,0)
            self.viewer.add_geom(self.max_line)

        if self.state is None: return None

        relativeDistance, relativeVelocity = self.state
        followerx = screen_width - 100 - relativeDistance
        leaderx = screen_width - 100
        #cartx = x[0]*scale+screen_width/2.0 # MIDDLE OF CART
        self.carttrans.set_translation(followerx, carty)
        self.carttrans2.set_translation(leaderx, carty)

        return self.viewer.render(return_rgb_array = mode=='rgb_array')

class ACCEnv3(ACCEnv):
    def __init__(self):
        super().__init__()
    
    def _step(self, action):
        if self.state[0] < 10 or self.state[0] < self.state[1]**2 / (2*0.8*self.A):
            return super()._step([self.A])
        else:
            return super()._step(action)

# class ACCEnvCurriculum(ACCEnv):
#     def __init__(self):
#         super().__init__()
#         self.prob_default=1.0
#         self.polytopes = []
    
#     def init_curriculum(self, prob_default,polytopes):
#         self.prob_default = prob_default
#         self.polytopes = polytopes
#         sum = 0.0
#         for i in range(len(self.polytopes)):
#             sum += self.polytopes[i][0]
#             self.polytopes[i][0] = sum
    
#     def _reset(self):
#         if random.uniform(0,1) <= self.prob_default:
#             return super()._reset()
#         else:
#             choice = random.uniform(0,1)
#             for poly in self.polytopes:
#                 if choice <= poly[0]:
#                     return reset_with_poly(poly[1])
    
#     def reset_with_poly(self, poly):
#         # sample point from halfspace polytope given in poly
#         # poly is a tuple (A,b) such that Ax <= b is the polytope
#         # A is a numpy array of shape (n,d) and b is a numpy array of shape (n)
#         # n is the number of inequalities and d is the dimension of the space
#         # the inequalities are of the form Ax <= b
#         # the point is sampled uniformly from the interior of the polytope
#         # the point is returned as a numpy array of shape (d)
#         # the point is guaranteed to be inside the polytope



gym.register(
      id='acc-variant-v0',
      entry_point=ACCEnv,
      max_episode_steps=410,  # todo edit
      reward_threshold=400.0, # todo edit
  )

gym.register(
      id='acc-variant-v1',
      entry_point=ACCEnv2,
      max_episode_steps=410,  # todo edit
      reward_threshold=400.0, # todo edit
  )


gym.register(
      id='acc-variant-v2',
      entry_point=ACCEnv3,
      max_episode_steps=410,  # todo edit
      reward_threshold=400.0, # todo edit
  )